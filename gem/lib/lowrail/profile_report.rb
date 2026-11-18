# frozen_string_literal: true

require "json"

module Lowrail
  # Reads lowrail-profile runs (DIR/runN/PID.tsv, written by lowrail/profile)
  # and writes DIR/report.md and DIR/report.json: lines in Rails, Ruby and gems
  # ranked by warm objects per request, grouped by gem, with the difference
  # between runs as the noise floor and matching entries of Lowrail's
  # contributions ledger; the app lines and controller actions that lead to
  # them; and jobs, mails and Action Cable actions apart from requests. Keys follow the census (RAILS/actionpack/lib/...,
  # GEM/name/path, RUBY/path), so a report can be set against `script/census rank`.
  #
  # Warm leaves out, per process, the objects a line allocated in the first
  # request that reached it: lazy one-time work (route table, template
  # compilation, i18n load) that the census removes with 50 warmup operations.
  class ProfileReport
    RAILS = %w[actioncable actionmailbox actionmailer actionpack actiontext actionview activejob activemodel
      activerecord activestorage activesupport railties].freeze
    RAILS_NAMES = { "actionpack" => ["Action Pack", "action_dispatch", "action_controller"],
      "actionview" => ["Action View"], "activerecord" => ["Active Record", "Arel"],
      "activesupport" => ["Active Support"], "activemodel" => ["Active Model"], "activejob" => ["Active Job"],
      "actiontext" => ["Action Text"], "activestorage" => ["Active Storage"], "actioncable" => ["Action Cable"],
      "actionmailer" => ["Action Mailer"], "railties" => ["Railties"] }.freeze
    RAILS_PATH = %r{/(?:gems|bundler/gems)/(?:rails-[^/]+/(#{RAILS.join("|")})|(#{RAILS.join("|")})-\d[^/]*)/(.+)\z}
    GEM_PATH = %r{/(?:gems|bundler/gems)/([^/]+?)-(\d[^/]*|\h{12})/(.+)\z}
    # Objects ObjectSpace.each_object never yields, so the census cannot see them.
    INTERNAL = %w[IMEMO Node ICLASS Zombie Moved NONE].freeze
    # Test clients and runners, when a test suite is the workload.
    HARNESS = /\A(?:rack-test|minitest|rspec-\w+|capybara|selenium-webdriver|webmock|vcr)\z/
    NOT_RANKED = ["app", "other", "lowrail-profile", "(no Ruby frame)"].freeze
    # Work that development and test mode do and production mostly does not:
    # the census (production, log level fatal, warmed up) never ranks these.
    MODE_ONLY = {
      "debug logging" => %r{/(?:log_subscriber|colorize_logging|structured_event_subscriber|event_reporter|logger)\.rb\z|\AGEM/logger/},
      "error page" => %r{/(?:exception_wrapper|debug_exceptions|backtrace_cleaner|show_exceptions)\.rb\z|\ARUBY/error_highlight/|\AGEM/prism/},
      "template compile" => %r{\AGEM/(?:erubi|herb|temple|slim|haml|hamlit)/|/action_view/template(?:\.rb|/handlers/)},
      "route build" => %r{/action_dispatch/journey/(?:gtg|nfa)/},
      # Vite Ruby checks the build on each lookup with autoBuild (its dev and
      # test default); Sprockets compiles live in test unless precompiled.
      "asset lookup" => %r{\AGEM/(?:propshaft|importmap-rails|vite_ruby|vite_rails|sprockets|sprockets-rails)/},
      "reload check" => %r{/active_support/(?:evented_)?file_update_checker\.rb\z}
    }.freeze

    KINDS = %w[request job mail cable].freeze
    KIND_TITLES = { "job" => "Jobs", "mail" => "Mails", "cable" => "Action Cable" }.freeze

    # App middleware that hands the request on is the nearest app frame of
    # the whole stack below it, so it is listed apart, not ranked.
    PASSES_ON = /(?:\A|[\s=(])@?app\.call\(/

    Site = Struct.new(:key, :group, :path, :line, :all, :warm, :reached, :types, :via, :kind, keyword_init: true)

    attr_reader :dir, :runs

    def initialize(dir, ledger: nil, top: 30)
      @dir = dir
      @top = top
      @ledger = ledger if ledger && File.exist?(ledger)
      @runs = Dir["#{dir}/run*"].select { File.directory?(_1) }.sort_by { _1[/\d+\z/].to_i }.map { load_run(_1) }
      raise "no runs with requests, jobs or mails under #{dir}" if @runs.empty? || @runs.all? { _1[:windows].values.sum == 0 }
    end

    def load_run(path)
      run = { name: File.basename(path), requests: 0, objects: 0, dropped: 0, processes: 0, roots: [],
        windows: Hash.new(0), sites: Hash.new { |h, k| h[k] = [0, 0, 0, 0] },
        actions: Hash.new { |h, k| h[k] = [0, 0, 0, 0] }, attrib: Hash.new { |h, k| h[k] = [0, 0] } }
      Dir["#{path}/*.tsv"].sort.each do |file|
        header, *rows = File.readlines(file, chomp: true)
        raise "#{file} is from an older lowrail-profile; run it again" unless header.start_with?("# lowrail-profile 2\t")
        meta = header.split("\t").drop(1).to_h { _1.split("=", 2) }
        run[:processes] += 1
        %i[requests objects dropped].each { run[_1] += Integer(meta.fetch(_1.to_s)) }
        KINDS.zip(meta.fetch("windows").split(",")) { |kind, n| run[:windows][kind] += Integer(n) }
        run[:roots] |= [meta["root"]]
        run[:ruby] ||= meta["ruby"]
        run[:rails_env] ||= meta["rails_env"]
        rows.each do |row|
          fields = row.split("\t")
          case fields[0]
          when "A"
            _, kind, name, windows, objects, first = fields
            action = run[:actions][[kind, name]]
            action[0] += Integer(windows)
            action[1] += Integer(objects)
            action[2] += Integer(first)
            action[3] += 1
          when "@"
            _, kind, name, file_path, line, caller_path, caller_line, count, first = fields
            attrib = run[:attrib][[kind, name, file_path, Integer(line), caller_path, Integer(caller_line)]]
            attrib[0] += Integer(count)
            attrib[1] += Integer(first)
          else
            file_path, line, type, count, reached, first, via, kind = fields
            site = run[:sites][[file_path, Integer(line), type, via, kind]]
            site[0] += Integer(count)
            site[1] += Integer(reached)
            site[2] += Integer(first)
            site[3] += Integer(count) if via == "1"
          end
        end
      end
      run[:attributed] = !run[:attrib].empty?
      run
    end

    def classify(path)
      @roots ||= @runs.flat_map { _1[:roots] }.uniq.compact.map { _1.end_with?("/") ? _1 : "#{_1}/" }
      libdir = RbConfig::CONFIG.fetch("rubylibdir") + "/"
      if path == "-" then ["(no Ruby frame)", path]
      elsif (m = path.match(RAILS_PATH)) then ["rails: #{m[1] || m[2]}", "RAILS/#{m[1] || m[2]}/#{m[3]}"]
      elsif (m = path.match(GEM_PATH))
        group = if default_gems.include?(m[1]) then "ruby default gem: #{m[1]}"
        elsif m[1].match?(HARNESS) then "test harness: #{m[1]}"
        else "gem: #{m[1]}"
        end
        [group, "GEM/#{m[1]}/#{m[3]}"]
      elsif (root = @roots.find { path.start_with?(_1) }) then ["app", "APP/#{path.delete_prefix(root)}"]
      elsif path.start_with?(libdir) then ["ruby stdlib", "RUBY/#{path.delete_prefix(libdir)}"]
      elsif path.start_with?("<internal:") then ["ruby core", "RUBY/#{path}"]
      elsif path.include?("/lowrail/profile") then ["lowrail-profile", path]
      else ["other", path]
      end
    end

    # By name, as the census does: a bundle may lock a newer release of one.
    def default_gems
      @default_gems ||= Dir[File.join(Gem.default_specifications_dir, "*.gemspec")]
        .map { File.basename(_1, ".gemspec")[/\A(.+)-\d[^-]*\z/, 1] } - %w[json]
    end

    # Every line of one kind of window, merged over the object types
    # ObjectSpace can see; per run objects per window (all and warm) and
    # windows reached.
    def sites(kind = "request")
      (@sites ||= {})[kind] ||= begin
        merged = {}
        @runs.each_with_index do |run, i|
          windows = run[:windows][kind]
          next if windows == 0
          run[:sites].each do |(path, line, type, _, site_kind), (count, reached, first, via)|
            next if site_kind != kind || INTERNAL.include?(type)
            group, key = classify(path)
            site = merged[[key, line]] ||= Site.new(key: key, group: group, path: path, line: line, via: 0, kind: kind,
              all: Array.new(@runs.size, 0.0), warm: Array.new(@runs.size, 0.0), reached: Array.new(@runs.size, 0),
              types: Hash.new(0))
            site.all[i] += count.fdiv(windows)
            site.warm[i] += (count - first).fdiv(windows)
            site.reached[i] = [site.reached[i], reached].max
            site.types[type] += count
            site.via += via
          end
        end
        merged.values
      end
    end

    def mean(values) = values.sum / values.size
    def noise(values) = values.size > 1 ? values.last - values.first : nil
    def ranked(kind = "request")
      (@ranked ||= {})[kind] ||= sites(kind).select { ranked?(_1) }.sort_by { [-mean(_1.warm), -mean(_1.all), _1.key, _1.line] }
    end
    def ranked?(site) = !NOT_RANKED.include?(site.group) && !site.group.start_with?("test harness")

    def source(site) = source_at(site.path, site.line)

    def source_at(path, line)
      @files ||= {}
      lines = (@files[path] ||= File.exist?(path) ? File.readlines(path, chomp: true) : [])
      text = lines[line - 1]&.strip
      method = lines[0, line].reverse_each.lazy.map { _1[/^\s*def\s+(?:self\.)?([^\s(;=]+=?)/, 1] }.find(&:itself)
      [text, method]
    end

    # Upstream pull requests from Lowrail's contributions ledger that reduce
    # allocations or time (by the ledger entry) and change this very line:
    # same gem, file and method, and the line's code is one the pull request
    # removes there (the app runs the code before it) or adds there (the app
    # may run it already). contributions-index.json is built by
    # script/profile-ledger. Closed, unmerged ones are left out.
    def ledger_matches(site)
      return [] unless (index = ledger_index)
      text, method = source(site)
      return [] unless method && text && text.length >= 6
      gem_name, file = ledger_file(site) || (return [])
      index.filter_map do |pr|
        next if pr["state"] == "closed" || !pr["allocation_work"] || !ledger_repo?(pr["repo"], gem_name)
        f = pr["files"].find { _1["path"] == file } or next
        change = f["methods"][method] or next
        removed, added = change["removed"].include?(text), change["added"].include?(text)
        ledger_label(pr, site, removed: removed) if removed || added
      end.compact.uniq.first(3)
    end

    def ledger_index
      return @ledger_index if defined?(@ledger_index)
      path = @ledger && File.join(File.dirname(@ledger), "contributions-index.json")
      @ledger_index = path && File.exist?(path) ? JSON.parse(File.read(path))["pulls"] : nil
    end

    # [gem or rails component or "ruby", path in its repository]
    def ledger_file(site)
      case site.key
      when %r{\ARAILS/(\w+)/(.+)\z} then [$1, "#{$1}/#{$2}"]
      when %r{\AGEM/([^/]+)/(.+)\z} then [$1, $2]
      when %r{\ARUBY/(?!<)(.+)\z} then ["ruby", "lib/#{$1}"]
      end
    end

    def ledger_repo?(repo, gem_name)
      name = repo.split("/").last.downcase.tr("_", "-").delete_suffix("-ruby").delete_prefix("ruby-")
      return RAILS.include?(gem_name) if repo == "rails/rails"
      return gem_name == "ruby" || default_gems.include?(gem_name) if repo == "ruby/ruby"
      name == gem_name.downcase.tr("_", "-")
    end

    # The version of the gem the line comes from (nil for git checkouts).
    def site_version(site)
      if site.key.start_with?("RUBY/")
        ruby = @runs.first[:ruby].to_s[/\Aruby (\d+\.\d+\.\d+)/, 1]
        return ruby && Gem::Version.new(ruby)
      end
      m = site.path.match(RAILS_PATH) ? site.path.match(%r{/(?:#{RAILS.join("|")})-(\d[\w.]*)/}) : site.path.match(GEM_PATH)
      version = m && m[m.size == 2 ? 1 : 2]
      Gem::Version.new(version) if version&.match?(/\A\d+(\.\w+)*\z/)
    end

    # nil when the line only matches code the pull request adds and the app's
    # version cannot show it runs that code (a git checkout, or not released).
    def ledger_label(pr, site, removed:)
      ref = pr["ref"]
      return removed ? "#{ref} open upstream work" : nil if pr["state"] == "open"
      released = pr["released_in"] && Gem::Version.new(pr["released_in"])
      version = site_version(site)
      return (released && version && version >= released ? "#{ref} merged, in #{released}, which this app runs" : nil) unless removed
      if released && version then version < released ? "#{ref} fixed in #{released}" : nil
      elsif released then "#{ref} fixed in #{released}, after this app's revision"
      else "#{ref} merged #{pr["merged_at"].to_s[0, 10]}, after this app's version, not released yet"
      end
    end

    def summary
      @runs.map do |run|
        { run: run[:name], processes: run[:processes], requests: run[:requests],
          objects_per_request: run[:requests] > 0 ? run[:objects].fdiv(run[:requests]) : 0.0, dropped: run[:dropped],
          windows: KINDS.to_h { [_1, run[:windows][_1]] } }
      end
    end

    def groups
      totals = Hash.new { |h, k| h[k] = { warm: 0.0, all: 0.0, sites: [] } }
      sites.each do |site|
        totals[site.group][:warm] += mean(site.warm)
        totals[site.group][:all] += mean(site.all)
        totals[site.group][:sites] << site
      end
      totals.sort_by { -_2[:warm] }
    end

    # Lines without dev/test-only work first, as production would see them;
    # the dev/test-only lines get their own table.
    def rows(list = ranked.reject { mode_only(_1) }, limit = @top)
      list.first(limit).each_with_index.map do |site, i|
        text, method = source(site)
        { rank: i + 1, site: "#{site.key}:#{site.line}", group: site.group, method: method, text: text,
          warm: site.warm.map { _1.round(2) }, noise: noise(site.warm)&.round(2), all: mean(site.all).round(2),
          reach: site.reached.zip(@runs).map { |r, run| (n = run[:windows][site.kind]) > 0 ? r.fdiv(n).round(3) : 0.0 },
          via_internal: site.via > 0, types: site.types.sort_by { -_2 }.first(2).map(&:first),
          ledger: ledger_matches(site), callers: top_callers(site), mode: mode_only(site) }
      end
    end

    def mode_rows = rows(ranked.select { mode_only(_1) }, [@top / 3, 10].max)

    def mode_only(site) = MODE_ONLY.find { |_, pattern| site.key.match?(pattern) }&.first

    # The run that recorded the nearest app frame (the repeat run).
    def attributed_run = @runs.reverse.find { _1[:attributed] }

    # Attributed allocations of one kind, merged per window name, line and
    # app line: [name, site key, line, app key or nil, app line, count, first].
    def attributions(kind = "request")
      (@attributions ||= {})[kind] ||= begin
        merged = Hash.new { |h, k| h[k] = [0, 0] }
        attributed_run&.dig(:attrib)&.each do |(k, name, path, line, caller_path, caller_line), (count, first)|
          next unless k == kind
          group, key = classify(path)
          app = caller_path == "-" ? nil : classify(caller_path)[1]
          entry = merged[[name, key, line, group, app, caller_line, path, caller_path]]
          entry[0] += count
          entry[1] += first
        end
        merged.map { |key, (count, first)| [*key, count, first] }
      end
    end

    def ranked_group?(group) = !NOT_RANKED.include?(group) && !group.start_with?("test harness")

    def mode_key?(key) = MODE_ONLY.any? { |_, pattern| key.match?(pattern) }

    # The app lines whose calls lead to the line's allocations (repeat run),
    # with their share; "no app frame" when none was on the stack.
    def top_callers(site)
      @callers ||= {}
      counts = (@callers[site.kind] ||= attributions(site.kind).each_with_object(Hash.new { |h, k| h[k] = Hash.new(0) }) do |row, acc|
        _, key, line, _, app, app_line, = row
        acc[[key, line]][app ? "#{app}:#{app_line}" : "no app frame"] += row[-2]
      end)[[site.key, site.line]]
      return [] if counts.nil? || counts.empty?
      total = counts.values.sum.to_f
      counts.sort_by { -_2 }.first(2).map { |caller, n| { caller: caller, share: (n / total).round(2) } }
    end

    # Your code: per app line, the objects that Rails, Ruby and gems allocate
    # below it per request (warm, leaving out each action's first request per
    # process), dev/test-only work apart, and the lines it reaches most.
    def app_lines(kind = "request")
      run = attributed_run or return []
      windows = run[:windows][kind]
      return [] if windows == 0
      lines = Hash.new { |h, k| h[k] = { warm: 0.0, all: 0.0, mode: 0.0, own: 0.0, sites: Hash.new(0.0), names: Hash.new(0.0) } }
      attributions(kind).each do |name, key, line, group, app, app_line, path, caller_path, count, first|
        next unless app
        entry = lines[[app, app_line, caller_path]]
        warm = (count - first).fdiv(windows)
        if group == "app"
          entry[:own] += warm if key == app && line == app_line
          next
        end
        next unless ranked_group?(group)
        entry[:all] += count.fdiv(windows)
        if mode_key?(key)
          entry[:mode] += warm
        else
          entry[:warm] += warm
          entry[:sites]["#{key}:#{line}"] += warm
          entry[:names][name] += warm
        end
      end
      lines = lines.reject { |_, e| e[:warm].round(2) == 0 && e[:mode].round(2) == 0 && e[:own].round(2) == 0 }
      lines.sort_by { |(app, line, _), e| [-e[:warm], -e[:mode], app, line] }.map do |(app, line, path), e|
        text, method = source_at(path, line)
        total = e[:warm]
        top = ->(hash) { hash.sort_by { -_2 }.first(3).map { |k, v| { name: k, share: total > 0 ? (v / total).round(2) : 0.0 } } }
        { line: "#{app}:#{line}", method: method, text: text, warm: e[:warm].round(2), mode: e[:mode].round(2),
          all: e[:all].round(2), own: e[:own].round(2), sites: top.(e[:sites]), actions: top.(e[:names]),
          passes_on: text.to_s.match?(PASSES_ON) }
      end
    end

    # Objects outside the app with no app line on the stack (middleware,
    # routing, the framework's own request handling), warm per request.
    def unattributed(kind = "request")
      run = attributed_run or return nil
      windows = run[:windows][kind]
      return nil if windows == 0
      attributions(kind).sum { |_, key, _, group, app, *, count, first| !app && ranked_group?(group) && !mode_key?(key) ? (count - first).fdiv(windows) : 0.0 }.round(2)
    end

    # Per window name (controller action, job, mailer action, channel action):
    # objects per window by run, warm leaving out its first window in each
    # process, and the lines outside the app and app lines it reaches most.
    def actions(kind = "request")
      (@actions ||= {})[kind] ||= begin
        names = @runs.flat_map { |run| run[:actions].keys.select { _1[0] == kind }.map(&:last) }.uniq
        attributed = Hash.new { |h, k| h[k] = { sites: Hash.new(0), apps: Hash.new(0) } }
        attributions(kind).each do |name, key, line, group, app, app_line, *, count, first|
          next unless ranked_group?(group) && !mode_key?(key)
          attributed[name][:sites]["#{key}:#{line}"] += count - first
          attributed[name][:apps]["#{app}:#{app_line}"] += count - first if app
        end
        attributed_index = @runs.index(attributed_run)
        names.map do |name|
          stats = @runs.map { |run| run[:actions][[kind, name]] if run[:actions].key?([kind, name]) }
          warm = stats.map { |windows, objects, first, processes| windows && windows > processes ? (objects - first).fdiv(windows - processes) : nil }
          all = stats.map { |windows, objects| windows ? objects.fdiv(windows) : nil }
          windows = stats.map { _1 ? _1[0] : 0 }
          a = attributed[name]
          denominator = attributed_index && (s = stats[attributed_index]) ? s[0] - s[3] : 0
          top = ->(hash) { denominator > 0 ? hash.sort_by { -_2 }.first(3).map { |k, v| { name: k, warm: v.fdiv(denominator).round(1) } } : [] }
          known = warm.compact
          { name: name == "-" ? nil : name, windows: windows, warm: warm.map { _1&.round(1) }, all: all.map { _1&.round(1) },
            noise: known.size > 1 && warm.first && warm.last ? (warm.last - warm.first).round(1) : nil,
            sort: known.empty? ? all.compact.max.to_f : mean(known), sites: top.(a[:sites]), apps: top.(a[:apps]) }
        end.sort_by { [_1[:warm].compact.empty? ? 1 : 0, -_1[:sort], _1[:name].to_s] }
      end
    end

    def noise_floor
      deltas = rows.filter_map { _1[:noise]&.abs }.sort
      return nil if deltas.empty?
      { top_lines: deltas.size, median_abs: deltas[deltas.size / 2].round(2), max_abs: deltas.last.round(2),
        moved_ge_1: deltas.count { _1 >= 1 } }
    end

    def cell(text) = "`#{text.to_s[0, 70].gsub("|", "\\|")}`"

    def callers_cell(callers) = callers.map { "`#{_1[:caller].delete_prefix("APP/")}` #{(_1[:share] * 100).round}%" }.join(", ")

    def table(rows)
      out = +"| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |\n" \
        "| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |\n"
      rows.each do |r|
        out << "| #{r[:rank]} | `#{r[:site]}`#{" †" if r[:via_internal]} | `#{r[:method]}` | #{r[:warm].join(" / ")} | " \
          "#{r[:noise]} | #{r[:all]} | #{(r[:reach].last * 100).round}% | #{r[:types].join(", ")} | " \
          "#{r[:ledger].join(", ")} | #{callers_cell(r[:callers])} | #{cell(r[:text])} |\n"
      end
      out
    end

    def app_lines_table(lines, limit)
      out = +"| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |\n" \
        "| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |\n"
      lines.first(limit).each_with_index do |l, i|
        sites = l[:sites].map { "`#{_1[:name]}` #{(_1[:share] * 100).round}%" }.join(", ")
        names = l[:actions].map { "#{_1[:name] || "(no name)"} #{(_1[:share] * 100).round}%" }.join(", ")
        out << "| #{i + 1} | `#{l[:line].delete_prefix("APP/")}` | #{"`#{l[:method]}`" if l[:method]} | #{l[:warm]} | #{l[:mode]} | #{l[:own]} | " \
          "#{sites} | #{names} | #{cell(l[:text])} |\n"
      end
      out
    end

    def actions_table(list, limit, label, per = "window")
      out = +"| # | #{label} | Count | Warm/#{per} | Δ | All/#{per} | Top lines outside the app (warm) | Top app lines (warm) |\n" \
        "| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |\n"
      list.first(limit).each_with_index do |a, i|
        sites = a[:sites].map { "`#{_1[:name]}` #{_1[:warm]}" }.join(", ")
        apps = a[:apps].map { "`#{_1[:name].delete_prefix("APP/")}` #{_1[:warm]}" }.join(", ")
        out << "| #{i + 1} | #{a[:name] || "(no #{label.downcase} name)"} | #{a[:windows].join(" / ")} | " \
          "#{a[:warm].map { _1 || "–" }.join(" / ")} | #{a[:noise]} | #{a[:all].compact.last} | #{sites} | #{apps} |\n"
      end
      out
    end

    def markdown
      command_file = File.join(dir, "command.txt")
      command = File.exist?(command_file) ? File.read(command_file).lines.first.strip : "?"
      out = +"# Lowrail profile\n\n"
      out << "Command: `#{command}`, #{@runs.first[:rails_env] || "?"} environment, #{@runs.first[:ruby]}.\n\n"
      out << "| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |\n" \
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n"
      summary.each do |s|
        w = s[:windows]
        out << "| #{s[:run]} | #{s[:processes]} | #{s[:requests]} | #{s[:objects_per_request].round(1)} | #{w["job"]} | " \
          "#{w["mail"]} | #{w["cable"]} | #{s[:dropped]} |\n"
      end
      if (floor = noise_floor)
        out << "\nNoise floor (last run minus first, warm, top #{floor[:top_lines]} lines): median |Δ| #{floor[:median_abs]}, " \
          "max |Δ| #{floor[:max_abs]} objects per request; #{floor[:moved_ge_1]} lines moved by 1 or more.\n"
      end
      lines = app_lines
      unless lines.empty?
        out << "\n## Your code\n\nThe app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per " \
          "request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems " \
          "left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, " \
          "template compilation, route building and asset lookup below the line, which production mostly does not do. " \
          "Own: objects the line itself allocates.\n\n"
        through, lines = lines.partition { _1[:passes_on] }
        out << app_lines_table(lines, @top)
        unless through.empty?
          out << "\nApp middleware that hands the request on (the stack below it, not its own work): " <<
            through.map { "`#{_1[:line].delete_prefix("APP/")}` #{_1[:warm]}" }.join(", ") << " warm objects per request.\n"
        end
        out << "\n#{unattributed} warm objects per request outside the app have no app line on the stack " \
          "(middleware, routing, rendering setup).\n" if unattributed
      end
      requests = actions
      unless requests.empty?
        out << "\n## Actions\n\nObjects per request by controller action and run, counting everything the request " \
          "allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; " \
          "– when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat " \
          "run, dev/test work left out).\n\n"
        out << actions_table(requests, @top, "Action", "req")
      end
      mode_total = ranked.select { mode_only(_1) }.sum { mean(_1.warm) }
      total = ranked.sum { mean(_1.warm) }
      out << "\n## Top lines outside the app\n\n" \
        "Warm: objects per request by run, without each line's first request per process (one-time work). " \
        "All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). " \
        "† charged from Ruby's `<internal:…>` code to this caller. Ledger: pull requests from Lowrail's contributions " \
        "ledger that change this line, and whether the app's version has them. From the app: the nearest app line on the stack (repeat " \
        "run). Dev/test-only work is listed separately below.\n\n"
      out << table(rows)
      unless (extra = mode_rows).empty?
        out << "\n## Dev/test-mode work\n\n#{mode_total.round(1)} of #{total.round(1)} warm objects per request outside " \
          "the app are work that test and development mode do and production mostly does not: debug logging, " \
          "error pages, template compilation, route building, asset lookup, code reload checks.\n\n"
        out << "| # | Kind | Line | Warm/req | Reach | From the app | Source |\n| ---: | --- | --- | ---: | ---: | --- | --- |\n"
        extra.each do |r|
          out << "| #{r[:rank]} | #{r[:mode]} | `#{r[:site]}`#{" †" if r[:via_internal]} | #{r[:warm].last} | " \
            "#{(r[:reach].last * 100).round}% | #{callers_cell(r[:callers])} | #{cell(r[:text])} |\n"
        end
      end
      out << "\n## By gem\n\n| Group | Warm/req | All/req | Top lines (warm) |\n| --- | ---: | ---: | --- |\n"
      groups.each do |group, data|
        top = data[:sites].sort_by { -mean(_1.warm) }.first(3).map { "`#{File.basename(_1.key)}:#{_1.line}` #{mean(_1.warm).round(1)}" }
        out << "| #{group} | #{data[:warm].round(1)} | #{data[:all].round(1)} | #{top.join(", ")} |\n"
      end
      out << outside_requests
      out
    end

    # Jobs, mails and Action Cable actions, counted like requests and kept
    # apart from them.
    def outside_requests
      kinds = KIND_TITLES.keys.select { |kind| @runs.any? { _1[:windows][kind] > 0 } }
      return "" if kinds.empty?
      out = +"\n## Outside requests\n\nJobs (`perform_now`), mails (each build and each delivery) and Action Cable " \
        "channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside " \
        "a request counts as part of that request.\n"
      kinds.each do |kind|
        label = { "job" => "Job", "mail" => "Mailer action", "cable" => "Channel action" }.fetch(kind)
        out << "\n### #{KIND_TITLES.fetch(kind)}\n\n"
        out << actions_table(actions(kind), @top, label)
        lines = rows(ranked(kind), [@top / 3, 10].max)
        next if lines.empty?
        out << "\n| # | Line | Warm/window | Reach | From the app | Source |\n| ---: | --- | ---: | ---: | --- | --- |\n"
        lines.each do |r|
          out << "| #{r[:rank]} | `#{r[:site]}`#{" †" if r[:via_internal]}#{" (#{r[:mode]})" if r[:mode]} | " \
            "#{r[:warm].join(" / ")} | #{(r[:reach].last * 100).round}% | #{callers_cell(r[:callers])} | #{cell(r[:text])} |\n"
        end
      end
      out
    end

    def write
      File.write(File.join(dir, "report.md"), markdown)
      File.write(File.join(dir, "report.json"), JSON.pretty_generate(to_h) + "\n")
    end

    def to_h
      command_file = File.join(dir, "command.txt")
      { command: File.exist?(command_file) ? File.read(command_file).lines.first.strip : nil,
        summary: summary, noise_floor: noise_floor, rows: rows, mode_rows: mode_rows,
        ranked: ranked.map { site_json(_1) }, app_lines: app_lines, unattributed: unattributed, actions: actions,
        outside_requests: (KINDS - ["request"]).to_h do |kind|
          [kind, { actions: actions(kind), ranked: ranked(kind).map { site_json(_1) } }]
        end,
        groups: groups.map { |g, d| { group: g, warm: d[:warm], all: d[:all] } } }
    end

    def site_json(site)
      { site: "#{site.key}:#{site.line}", group: site.group, mode: mode_only(site), warm: site.warm, all: site.all,
        reached: site.reached }
    end
  end
end
