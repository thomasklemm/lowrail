# frozen_string_literal: true

require "json"

module Lowrail
  # Reads lowrail-profile runs (DIR/runN/PID.tsv, written by lowrail/profile)
  # and writes DIR/report.md and DIR/report.json: lines in Rails, Ruby and gems
  # ranked by warm objects per request, grouped by gem, with the difference
  # between runs as the noise floor and matching entries of Lowrail's
  # contributions ledger. Keys follow the census (RAILS/actionpack/lib/...,
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
    GENERIC_METHODS = %w[call initialize each new method_missing respond_to_missing? to_s inspect [] []= == fetch
      block].freeze
    NOT_RANKED = ["app", "other", "lowrail-profile", "(no Ruby frame)"].freeze
    # Work that development and test mode do and production mostly does not:
    # the census (production, log level fatal, warmed up) never ranks these.
    MODE_ONLY = {
      "debug logging" => %r{/(?:log_subscriber|colorize_logging|structured_event_subscriber|event_reporter|logger)\.rb\z|\AGEM/logger/},
      "error page" => %r{/(?:exception_wrapper|debug_exceptions|backtrace_cleaner|show_exceptions)\.rb\z|\ARUBY/error_highlight/|\AGEM/prism/},
      "template compile" => %r{\AGEM/(?:erubi|herb)/|/action_view/template(?:\.rb|/handlers/)},
      "route build" => %r{/action_dispatch/journey/(?:gtg|nfa)/},
      "asset lookup" => %r{\AGEM/(?:propshaft|importmap-rails)/}
    }.freeze

    Site = Struct.new(:key, :group, :path, :line, :all, :warm, :reached, :types, :via, keyword_init: true)

    attr_reader :dir, :runs

    def initialize(dir, ledger: nil, top: 30)
      @dir = dir
      @top = top
      @ledger = ledger if ledger && File.exist?(ledger)
      @runs = Dir["#{dir}/run*"].select { File.directory?(_1) }.sort_by { _1[/\d+\z/].to_i }.map { load_run(_1) }
      raise "no runs with requests under #{dir}" if @runs.empty? || @runs.all? { _1[:requests] == 0 }
    end

    def load_run(path)
      run = { name: File.basename(path), requests: 0, objects: 0, dropped: 0, processes: 0, roots: [],
        sites: Hash.new { |h, k| h[k] = [0, 0, 0, 0] } }
      Dir["#{path}/*.tsv"].sort.each do |file|
        header, *rows = File.readlines(file, chomp: true)
        meta = header.split("\t").drop(1).to_h { _1.split("=", 2) }
        run[:processes] += 1
        %i[requests objects dropped].each { run[_1] += Integer(meta.fetch(_1.to_s)) }
        run[:roots] |= [meta["root"]]
        run[:ruby] ||= meta["ruby"]
        run[:rails_env] ||= meta["rails_env"]
        rows.each do |row|
          if row.start_with?("@\t")
            _, file_path, line, caller_path, caller_line, count = row.split("\t")
            (callers[[file_path, Integer(line)]] ||= Hash.new(0))[[caller_path, Integer(caller_line)]] += Integer(count)
            next
          end
          file_path, line, type, count, reached, first, via = row.split("\t")
          site = run[:sites][[file_path, Integer(line), type, via]]
          site[0] += Integer(count)
          site[1] += Integer(reached)
          site[2] += Integer(first)
          site[3] += Integer(count) if via == "1"
        end
      end
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

    # Every line, merged over the object types ObjectSpace can see; per run
    # objects per request (all and warm) and requests reached.
    def sites
      @sites ||= begin
        merged = {}
        @runs.each_with_index do |run, i|
          next if run[:requests] == 0
          run[:sites].each do |(path, line, type), (count, reached, first, via)|
            next if INTERNAL.include?(type)
            group, key = classify(path)
            site = merged[[key, line]] ||= Site.new(key: key, group: group, path: path, line: line, via: 0,
              all: Array.new(@runs.size, 0.0), warm: Array.new(@runs.size, 0.0), reached: Array.new(@runs.size, 0),
              types: Hash.new(0))
            site.all[i] += count.fdiv(run[:requests])
            site.warm[i] += (count - first).fdiv(run[:requests])
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
    def ranked = @ranked ||= sites.select { ranked?(_1) }.sort_by { [-mean(_1.warm), -mean(_1.all), _1.key, _1.line] }
    def ranked?(site) = !NOT_RANKED.include?(site.group) && !site.group.start_with?("test harness")

    def source(site)
      @files ||= {}
      lines = (@files[site.path] ||= File.exist?(site.path) ? File.readlines(site.path, chomp: true) : [])
      text = lines[site.line - 1]&.strip
      method = lines[0, site.line].reverse_each.lazy.map { _1[/^\s*def\s+(?:self\.)?([^\s(;=]+=?)/, 1] }.find(&:itself)
      [text, method]
    end

    # Ledger entries that name the line's method in a code span and also name
    # its file, gem or Rails component.
    def ledger_matches(site)
      return [] unless @ledger
      @bullets ||= File.read(@ledger).split(/^(?=\s*- )/).filter_map do |text|
        ref = text[/\[((?:[\w.-]+\/[\w.-]+)?#\d+)\]/, 1]
        { text: text, ref: ref } if ref
      end
      _, method = source(site)
      return [] if method.nil? || method.length < 5 || GENERIC_METHODS.include?(method)
      code = /`[^`\n]*(?<![\w])#{Regexp.escape(method)}(?![\w?!])[^`\n]*`/
      owner = site.group.split(": ", 2).last
      names = /(?<![\w-])(?:#{[File.basename(site.key), owner, *RAILS_NAMES.fetch(owner, [])].map { Regexp.escape(_1) }.join("|")})(?![\w-])/
      @bullets.select { |b| b[:text].match?(code) && b[:text].match?(names) }.map { _1[:ref] }.uniq.first(3)
    end

    def summary
      @runs.map do |run|
        { run: run[:name], processes: run[:processes], requests: run[:requests],
          objects_per_request: run[:requests] > 0 ? run[:objects].fdiv(run[:requests]) : 0.0, dropped: run[:dropped] }
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
          reach: site.reached.zip(@runs).map { |r, run| run[:requests] > 0 ? r.fdiv(run[:requests]).round(3) : 0.0 },
          via_internal: site.via > 0, types: site.types.sort_by { -_2 }.first(2).map(&:first),
          ledger: ledger_matches(site), callers: top_callers(site), mode: mode_only(site) }
      end
    end

    def mode_rows = rows(ranked.select { mode_only(_1) }, [@top / 3, 10].max)

    def mode_only(site) = MODE_ONLY.find { |_, pattern| site.key.match?(pattern) }&.first

    def callers = @callers ||= {}

    # The app lines whose calls lead to the line's allocations (watched in the
    # repeat run), with their share; "no app frame" when none was on the stack.
    def top_callers(site)
      counts = callers[[site.path, site.line]] or return []
      total = counts.values.sum.to_f
      counts.sort_by { -_2 }.first(2).map do |(path, line), n|
        where = path == "-" ? "no app frame" : "#{classify(path)[1]}:#{line}"
        { caller: where, share: (n / total).round(2) }
      end
    end

    def noise_floor
      deltas = rows.filter_map { _1[:noise]&.abs }.sort
      return nil if deltas.empty?
      { top_lines: deltas.size, median_abs: deltas[deltas.size / 2].round(2), max_abs: deltas.last.round(2),
        moved_ge_1: deltas.count { _1 >= 1 } }
    end

    def table(rows)
      out = +"| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |\n" \
        "| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |\n"
      rows.each do |r|
        callers = r[:callers].map { "`#{_1[:caller].delete_prefix("APP/")}` #{(_1[:share] * 100).round}%" }
        out << "| #{r[:rank]} | `#{r[:site]}`#{" †" if r[:via_internal]} | `#{r[:method]}` | #{r[:warm].join(" / ")} | " \
          "#{r[:noise]} | #{r[:all]} | #{(r[:reach].last * 100).round}% | #{r[:types].join(", ")} | " \
          "#{r[:ledger].join(", ")} | #{callers.join(", ")} | `#{r[:text].to_s[0, 70].gsub("|", "\\|")}` |\n"
      end
      out
    end

    def markdown
      command_file = File.join(dir, "command.txt")
      command = File.exist?(command_file) ? File.read(command_file).lines.first.strip : "?"
      out = +"# Lowrail profile\n\n"
      out << "Command: `#{command}`, #{@runs.first[:rails_env] || "?"} environment, #{@runs.first[:ruby]}.\n\n"
      out << "| Run | Processes | Requests | Objects per request | Dropped |\n| --- | ---: | ---: | ---: | ---: |\n"
      summary.each { out << "| #{_1[:run]} | #{_1[:processes]} | #{_1[:requests]} | #{_1[:objects_per_request].round(1)} | #{_1[:dropped]} |\n" }
      if (floor = noise_floor)
        out << "\nNoise floor (last run minus first, warm, top #{floor[:top_lines]} lines): median |Δ| #{floor[:median_abs]}, " \
          "max |Δ| #{floor[:max_abs]} objects per request; #{floor[:moved_ge_1]} lines moved by 1 or more.\n"
      end
      mode_total = ranked.select { mode_only(_1) }.sum { mean(_1.warm) }
      total = ranked.sum { mean(_1.warm) }
      out << "\n## Top lines outside the app\n\n" \
        "Warm: objects per request by run, without each line's first request per process (one-time work). " \
        "All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). " \
        "† charged from Ruby's `<internal:…>` code to this caller. Ledger: Lowrail contributions that name the " \
        "line's method and its file, gem or component. From the app: the nearest app line on the stack (repeat " \
        "run). Dev/test-only work is listed separately below.\n\n"
      out << table(rows)
      unless (extra = mode_rows).empty?
        out << "\n## Dev/test-mode work\n\n#{mode_total.round(1)} of #{total.round(1)} warm objects per request outside " \
          "the app are work that test and development mode do and production mostly does not: debug logging, " \
          "error pages, template compilation, route building, asset lookup.\n\n"
        out << "| # | Kind | Line | Warm/req | Reach | From the app | Source |\n| ---: | --- | --- | ---: | ---: | --- | --- |\n"
        extra.each do |r|
          callers = r[:callers].map { "`#{_1[:caller].delete_prefix("APP/")}` #{(_1[:share] * 100).round}%" }
          out << "| #{r[:rank]} | #{r[:mode]} | `#{r[:site]}`#{" †" if r[:via_internal]} | #{r[:warm].last} | " \
            "#{(r[:reach].last * 100).round}% | #{callers.join(", ")} | `#{r[:text].to_s[0, 70].gsub("|", "\\|")}` |\n"
        end
      end
      out << "\n## By gem\n\n| Group | Warm/req | All/req | Top lines (warm) |\n| --- | ---: | ---: | --- |\n"
      groups.each do |group, data|
        top = data[:sites].sort_by { -mean(_1.warm) }.first(3).map { "`#{File.basename(_1.key)}:#{_1.line}` #{mean(_1.warm).round(1)}" }
        out << "| #{group} | #{data[:warm].round(1)} | #{data[:all].round(1)} | #{top.join(", ")} |\n"
      end
      out
    end

    def write
      File.write(File.join(dir, "report.md"), markdown)
      File.write(File.join(dir, "report.json"), JSON.pretty_generate(summary: summary, noise_floor: noise_floor,
        rows: rows, mode_rows: mode_rows,
        ranked: ranked.map { { site: "#{_1.key}:#{_1.line}", group: _1.group, mode: mode_only(_1), warm: _1.warm, all: _1.all,
          reached: _1.reached } },
        groups: groups.map { |g, d| { group: g, warm: d[:warm], all: d[:all] } }) + "\n")
    end
  end
end
