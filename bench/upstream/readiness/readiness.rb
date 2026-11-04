# frozen_string_literal: true

# Rails readiness runner (docs/upstream/readiness.md). Runs each suite of a manifest on a base and a candidate
# Rails tree, once per seed, through the ecosystem harness (../ecosystem/eco.sh, Gemfile.eco), and flags what fails
# only on the candidate. Every run is cached under WORK/state, keyed by its inputs, so a restart resumes.
#
#   ruby readiness.rb MANIFEST.yml [--work DIR] [--out DIR] [--only a,b] [--jobs N] [--fresh a,b] [--report]
require "digest"
require "fileutils"
require "time"
require "json"
require "open3"
require "optparse"
require "shellwords"
require "yaml"

module Readiness
  HERE = __dir__
  ECO = File.expand_path("../ecosystem", HERE)
  TREES = %w[base cand].freeze
  LOCK = Mutex.new
  PREP = Mutex.new

  module_function

  def log(msg) = LOCK.synchronize { $stderr.puts "[#{Time.now.strftime("%H:%M:%S")}] #{msg}" }
  def sha(obj) = Digest::SHA256.hexdigest(obj.is_a?(String) ? obj : JSON.generate(obj))

  def sh!(cmd, chdir: nil, env: {}, out: nil)
    ok = if out
      system(env, cmd, chdir: chdir || Dir.pwd, out: [out, "a"], err: [:child, :out])
    else
      system(env, cmd, chdir: chdir || Dir.pwd, exception: false)
    end
    raise "failed: #{cmd}" unless ok
  end

  def git(*args) = Open3.capture2("git", *args).then { |o, s| s.success? ? o.strip : raise("git #{args.join(" ")} failed") }

  # A checkout of REPO at SHA in DIR, as a worktree of one clone per repository.
  def checkout(clone, url, ref, dir)
    commit = fetch(clone, url, ref)
    sh!("git -C #{clone.shellescape} worktree add -q --detach #{dir.shellescape} #{commit}") unless Dir.exist?(dir)
    sh!("git -C #{dir.shellescape} checkout -q --force --detach #{commit} && git -C #{dir.shellescape} clean -qfdx")
    commit
  end

  def fetch(clone, url, ref)
    sh!("git clone -q --filter=blob:none --no-checkout #{url.shellescape} #{clone.shellescape}") unless Dir.exist?(clone)
    resolve(clone, ref)
  end

  # A SHA or tag resolves locally; anything else (a branch) is fetched, so a restart picks up its new head.
  def resolve(clone, ref)
    local = ref.match?(/\A\h{7,40}\z/) || system("git", "-C", clone, "rev-parse", "-q", "--verify", "refs/tags/#{ref}", out: File::NULL)
    begin
      return git("-C", clone, "rev-parse", "--verify", "-q", "#{ref}^{commit}") if local
    rescue RuntimeError
      nil
    end
    sh!("git -C #{clone.shellescape} fetch -q origin #{ref.shellescape}")
    git("-C", clone, "rev-parse", "--verify", "-q", "FETCH_HEAD^{commit}")
  end

  class Round
    attr_reader :m, :work, :out, :seeds

    def initialize(path, work: nil, out: nil)
      @path = File.expand_path(path)
      @m = YAML.safe_load_file(@path, aliases: true)
      name = File.basename(path, ".*")
      @work = File.expand_path(work || "~/src/readiness/#{name}")
      @out = File.expand_path(out || File.join(@work, "out"))
      @seeds = m.fetch("seeds")
      raise "seeds: give two (A for run 1, B for run 2)" unless @seeds.size == 2
      FileUtils.mkdir_p([@work, @out])
    end

    def ruby = m.fetch("ruby")
    def ruby_v = @ruby_v ||= `mise exec ruby@#{ruby} -- ruby -v`.strip
    def suites = m.fetch("suites")

    def rails
      @rails ||= begin
        clone = File.join(work, "rails.git")
        TREES.to_h do |t|
          ref = m.dig("rails", t == "base" ? "base" : "candidate")
          dir = File.join(work, "rails-#{t}")
          commit = Readiness.checkout(clone, m.dig("rails", "repo") || "https://github.com/rails/rails", ref, dir)
          [t, { "ref" => ref, "sha" => commit, "version" => File.read(File.join(dir, "RAILS_VERSION")).strip }]
        end
      end
    end

    def run(only: nil, jobs: 1, fresh: [])
      rails
      names = only || suites.keys
      fresh.each { |n| FileUtils.rm_rf(File.join(work, "state", n)) }
      queue = Queue.new
      names.each { queue << _1 }
      queue.close
      Array.new(jobs) do
        Thread.new do
          while (name = queue.pop)
            begin
              Suite.new(self, name, suites.fetch(name)).call
            rescue => e
              Readiness.log "#{name}: runner error #{e.class}: #{e.message}"
            end
          end
        end
      end.each(&:join)
      report
    end

    def report
      results = suites.keys.filter_map { |n| f = File.join(work, "state", n, "suite.json"); JSON.parse(File.read(f)) if File.exist?(f) }
      Report.new(self, results).write
    end
  end

  class Suite
    def initialize(round, name, cfg)
      @r, @name, @cfg = round, name, cfg
      @state = File.join(round.work, "state", name)
      FileUtils.mkdir_p(@state)
    end

    def framework = @cfg.fetch("framework")
    def clone = File.join(@r.work, "suites", "#{@name}.git")
    def dir(t) = File.join(@r.work, "suites", @name, t)
    def gemfile = @cfg.fetch("gemfile", "Gemfile")
    def eco_lock(t) = File.join(dir(t), File.dirname(gemfile), "Gemfile.eco-#{t}.lock")

    def env(t, extra = {})
      { "ECO_ROOT" => @r.work, "ECO_RUBY" => @r.ruby, "ECO_GEMFILE" => gemfile, "BUNDLE_PATH" => File.join(@r.work, "bundle", @name),
        "ECO_BUMPS" => JSON.generate(@cfg.fetch("bumps", {})) }.merge(@cfg.fetch("env", {}).transform_values(&:to_s)).merge(extra)
    end

    def eco(t, cmd) = "#{File.join(ECO, "eco.sh").shellescape} #{dir(t).shellescape} #{t} bash -c #{cmd.shellescape}"

    # Explicit inputs: everything that is not Rails, Ruby, the lock or the seed but changes the result.
    def inputs
      shims = @cfg.fetch("shims", []).map do |s|
        s.is_a?(Hash) ? { "patch" => s["patch"], "sha" => Readiness.sha(File.read(File.expand_path(s["patch"], Readiness::HERE))) } : s
      end
      @cfg.slice("repo", "framework", "gemfile", "lock", "env", "bumps", "setup", "test", "single").merge("shims" => shims)
    end

    def call
      t0 = Time.now
      @commit = Readiness.fetch(clone, @cfg.fetch("repo"), @cfg.fetch("ref"))
      prep = TREES.to_h { |t| [t, PREP.synchronize { prepare(t) }] }
      runs = []
      @r.seeds.each_with_index do |seed, i|
        TREES.each { |t| runs << (prep[t]["ok"] ? run(t, i + 1, seed, prep[t]) : { "tree" => t, "n" => i + 1, "seed" => seed, "loaded" => false, "stage" => "prepare", "signature" => prep[t]["signature"] }) }
      end
      result = Classify.new(self, prep, runs).call
      File.write(File.join(@state, "suite.json"), JSON.pretty_generate(result))
      Readiness.log "#{@name}: done in #{(Time.now - t0).round}s, #{result["flags"].size} flags"
    end

    def prep_key(t)
      base_lock = t == "cand" ? JSON.parse(File.read(File.join(@state, "prepare-base.json")))["lock_sha"] : nil
      Readiness.sha([@name, @commit, @r.rails[t]["sha"], @r.ruby_v, inputs, base_lock])
    end

    def prepared?(t)
      f = File.join(@state, "prepare-#{t}.json")
      File.exist?(f) && JSON.parse(File.read(f))["key"] == prep_key(t)
    rescue Errno::ENOENT
      false
    end

    # Checkout, shims, lock seeding, bundle and setup for one tree. Cached by prep_key.
    def prepare(t)
      f = File.join(@state, "prepare-#{t}.json")
      key = prep_key(t)
      return JSON.parse(File.read(f)) if prepared?(t)
      Readiness.log "#{@name}: preparing #{t} (Rails #{@r.rails[t]["sha"][0, 10]})"
      commit = Readiness.checkout(clone, @cfg.fetch("repo"), @commit, dir(t))
      log = File.join(@state, "prepare-#{t}.log")
      File.write(log, "")
      seed_lock(t)
      steps = @cfg.fetch("shims", []).map { |s| s.is_a?(Hash) ? "git apply #{File.expand_path(s["patch"], Readiness::HERE).shellescape}" : s }
      res = { "key" => key, "commit" => commit, "ok" => true }
      begin
        steps.each { |s| Readiness.sh!(s, chdir: dir(t), env: env(t), out: log) }
        Readiness.sh!(eco(t, "ruby -v"), chdir: dir(t), env: env(t), out: log)
        @cfg.fetch("setup", []).each { |s| Readiness.sh!(eco(t, s), chdir: dir(t), env: env(t), out: log) }
      rescue RuntimeError => e
        res.merge!("ok" => false, "signature" => "#{Parse.crash_signature(File.read(log), @r) || e.message} (prepare)")
      end
      res["lock_sha"] = File.exist?(eco_lock(t)) ? Readiness.sha(File.read(eco_lock(t))) : nil
      File.write(f, JSON.generate(res))
      res
    end

    # The base lock starts from the suite's own lock (if it has one), the candidate lock from the base lock, so
    # only Rails and what Rails itself requires differ.
    def seed_lock(t)
      src = t == "base" ? File.join(dir(t), @cfg.fetch("lock", "#{gemfile}.lock")) : eco_lock("base")
      FileUtils.cp(src, eco_lock(t)) if File.exist?(src)
    end

    def seed_env(seed, extra_testopts = "")
      { "SEED" => seed.to_s, "TESTOPTS" => "--seed=#{seed} #{extra_testopts}".strip }
    end

    def run(t, n, seed, prep)
      key = Readiness.sha([@name, prep["commit"], @r.rails[t]["sha"], prep["lock_sha"], @r.ruby_v, seed, inputs])
      f = File.join(@state, "run-#{t}-#{n}-#{key[0, 12]}.json")
      return JSON.parse(File.read(f)) if File.exist?(f)
      Readiness.log "#{@name}: #{t} run #{n} (seed #{seed})"
      res = execute(t, @cfg.fetch("test"), seed, f.sub(/\.json\z/, ""))
      res.merge!("tree" => t, "n" => n, "seed" => seed, "key" => key)
      File.write(f, JSON.generate(res))
      res
    end

    def execute(t, cmd, seed, stem, extra_testopts: "")
      log, json = "#{stem}.log", "#{stem}.rspec.json"
      FileUtils.rm_f([log, json])
      e = env(t, seed_env(seed, extra_testopts))
      e["SPEC_OPTS"] = "--seed #{seed} --format progress --format json --out #{json}" if framework == "rspec"
      timeout = @r.m.fetch("timeout", 3600)
      t0 = Time.now
      system(e, "timeout --kill-after=30 #{timeout} #{eco(t, cmd)}", chdir: dir(t), out: log, err: [:child, :out])
      status = $?.exitstatus
      res = Parse.call(framework, log, json, @r).merge("status" => status, "secs" => (Time.now - t0).round, "log" => log)
      res.merge!("loaded" => false, "signature" => "timed out after #{timeout}s") if [124, 137].include?(status)
      res
    end

    # One test alone on tree t, `times` times; returns how often it failed and how often it did not run.
    def alone(t, test, times)
      seed = @r.seeds.first
      f = File.join(@state, "alone-#{t}-#{Readiness.sha([test, run_key_base(t)])[0, 12]}.json")
      return JSON.parse(File.read(f)) if File.exist?(f)
      counts = { "failed" => 0, "passed" => 0, "not_run" => 0 }
      times.times do |i|
        stem = f.sub(/\.json\z/, "-#{i}")
        res = if framework == "rspec"
          execute(t, (@cfg["single"] || "rspec {id}").gsub("{id}", test.shellescape), seed, stem)
        else
          re = "/^#{Regexp.escape(test)}$/"
          @cfg["single"] ? execute(t, @cfg["single"].gsub("{id}", test.shellescape).gsub("{name_re}", re.shellescape), seed, stem)
                         : execute(t, @cfg.fetch("test"), seed, stem, extra_testopts: "--name=#{re}".shellescape)
        end
        k = if !res["loaded"] || res["total"].zero? then "not_run"
        elsif res["failures"].key?(test) then "failed"
        else "passed"
        end
        counts[k] += 1
      end
      File.write(f, JSON.generate(counts))
      counts
    end

    def run_key_base(t)
      p = JSON.parse(File.read(File.join(@state, "prepare-#{t}.json")))
      [@name, p["commit"], @r.rails[t]["sha"], p["lock_sha"], @r.ruby_v, inputs]
    end

    def lock_diff
      return nil unless File.exist?(eco_lock("base")) && File.exist?(eco_lock("cand"))
      o, = Open3.capture2({ "BUNDLE_GEMFILE" => eco_lock("cand").delete_suffix(".lock") }, "mise", "exec", "ruby@#{@r.ruby}", "--", "ruby",
        File.join(ECO, "eco-locks.rb"), eco_lock("base"), eco_lock("cand"), chdir: dir("cand"))
      o.lines.map(&:strip)
    end

    attr_reader :name, :cfg, :r
  end

  module Parse
    module_function

    EXC = /\A([A-Z]\w*(?:::[A-Z]\w*)*):?\z/

    # Strip what differs between trees and runs but not between causes: object addresses, tmp paths, the
    # checkout and gem locations, line numbers inside Rails, the two Rails version strings.
    def norm(s, round)
      s = s.to_s.dup
      s.gsub!(%r{#{Regexp.escape(round.work)}/rails-(?:base|cand)/(\S+?\.rb):\d+}, 'RAILS/\1')
      s.gsub!(%r{#{Regexp.escape(round.work)}/rails-(?:base|cand)/}, "RAILS/")
      s.gsub!(%r{#{Regexp.escape(round.work)}/suites/[^/]+/(?:base|cand)/}, "")
      s.gsub!(%r{/\S*?/gems/(?:ruby/)?[\d.]+/(?:bundler/)?gems/}, "GEMS/")
      s.gsub!(%r{/\S*?/lib/ruby/[\d.]+/}, "RUBYLIB/")
      round.rails.each_value { |r| s.gsub!(r["version"], "RAILS_VERSION") }
      s.gsub!(/0x\h+/, "0xX")
      s.gsub!(%r{/tmp/[^\s:'",)\]]+}, "/tmp/X")
      s.gsub!(/\d+(?:\.\d+)? ?(?:ms|seconds|s)\b/, "Ns")
      s.gsub(/\s+/, " ").strip[0, 200]
    end

    def call(framework, log, json, round)
      text = File.exist?(log) ? File.binread(log).force_encoding("UTF-8").scrub : ""
      res = framework == "rspec" ? rspec(text, json, round) : minitest(text, round)
      unless res["loaded"]
        res["signature"] ||= crash_signature(text, round) || "no test totals in output"
      end
      res
    end

    def rspec(text, json, round)
      return { "loaded" => false, "total" => 0, "failures" => {} } unless File.exist?(json)
      j = JSON.parse(File.read(json))
      fails = j["examples"].select { _1["status"] == "failed" }.to_h do |ex|
        e = ex["exception"] || {}
        [ex["id"], { "signature" => norm("#{e["class"]}: #{e["message"].to_s.lines.reject { _1.strip.empty? }.first}", round), "desc" => ex["full_description"].to_s[0, 160] }]
      end
      outside = j["messages"].to_a.select { _1.include?("An error occurred") }.to_h do |msg|
        where = msg[/An error occurred (?:while loading (\S+?)\.?$|in (.+?)\.$)/, 1] || msg[/An error occurred in (.+?)\./, 1] || "outside examples"
        ["load: #{where}", { "signature" => outside_signature(msg, round), "desc" => "error outside examples" }]
      end
      total = j.dig("summary", "example_count").to_i
      res = { "loaded" => true, "total" => total, "failures" => fails.merge(outside) }
      if total.zero? && (outside.any? || j.dig("summary", "errors_outside_of_examples_count").to_i.positive?)
        res.merge!("loaded" => false, "signature" => outside.values.map { _1["signature"] }.tally.max_by(&:last)&.first)
        res["load_errors"] = outside.size
      end
      res
    end

    def outside_signature(msg, round)
      lines = msg.lines.map(&:rstrip)
      i = lines.index { _1.strip.match?(EXC) && !_1.strip.start_with?("Failure/Error") }
      return norm(lines.reject(&:empty?)[1], round) unless i
      norm("#{lines[i].strip.chomp(":")}: #{lines[(i + 1)..].find { !_1.strip.empty? }&.strip}", round)
    end

    def minitest(text, round)
      lines = text.lines
      totals = lines.grep(/^\d+ (?:runs|tests), \d+ assertions/)
      return { "loaded" => false, "total" => 0, "failures" => {} } if totals.empty?
      fails = {}
      lines.each_with_index do |l, i|
        next unless l =~ /^\s*(?:\d+\) )?(Failure|Error):\s*$/
        kind = $1
        id = lines[i + 1].to_s.strip.sub(/ \[.*\]:?\z/, "").sub(/:\z/, "")
        msg = lines[(i + 2)..].to_a.find { !_1.strip.empty? }.to_s.strip
        sig = kind == "Error" ? msg : "Minitest::Assertion: #{msg}"
        fails[id] ||= { "signature" => norm(sig, round), "desc" => id }
      end
      { "loaded" => true, "total" => totals.sum { _1[/\d+/].to_i }, "failures" => fails }
    end

    # The exception that stopped a process before any test ran: Ruby's "file:line:in 'm': msg (Class)",
    # a Bundler resolution error, or nil.
    def crash_signature(text, round)
      if (l = text.lines.reverse.find { _1 =~ /:in .*: .+ \(([A-Z]\w*(?:::\w+)*)\)$/ })
        cls = l[/\(([A-Z]\w*(?:::\w+)*)\)$/, 1]
        msg = l.sub(/\A.*?:in [^:]*: /, "").sub(/ \(#{Regexp.escape(cls)}\)\s*\z/, "")
        return norm("#{cls}: #{msg}", round)
      end
      l = text.lines.find { _1 =~ /Could not find|could not find compatible|Bundler could not|Gem::MissingSpec|LoadError|NameError/ }
      l && norm(l, round)
    end
  end

  # Turns four runs (base and candidate, seeds A and B) into flags.
  class Classify
    # Assertion messages embed the values under test, so two assertion failures count as the same error;
    # RSpec wraps an assertion plus later hook errors in MultipleExceptionError.
    ASSERTION = /\A(?:RSpec::Expectations::ExpectationNotMetError|RSpec::Core::MultipleExceptionError|Minitest::Assertion):/

    def self.kind(sig) = sig.to_s.match?(ASSERTION) ? "assertion" : sig

    def initialize(suite, prep, runs)
      @s, @prep, @runs = suite, prep, runs
    end

    def by(t) = @runs.select { _1["tree"] == t }.sort_by { _1["n"] }

    def call
      flags = []
      unloaded = @runs.reject { _1["loaded"] }
      unloaded.group_by { _1["tree"] }.each do |t, rs|
        flags << { "class" => "suite-did-not-load", "test" => "(suite)", "tree" => t,
                   "signature" => rs.first["signature"].to_s, "detail" => "#{t} runs #{rs.map { _1["n"] }.join(",")} did not load" +
                     (rs.first["stage"] ? " (#{rs.first["stage"]})" : "") + (rs.first["load_errors"] ? ", #{rs.first["load_errors"]} load errors" : "") }
      end
      if unloaded.empty?
        totals = @runs.map { _1["total"] }
        if totals.uniq.size > 1
          flags << { "class" => "test-count-mismatch", "test" => "(suite)", "signature" => "test count differs",
                     "detail" => @runs.map { "#{_1["tree"]}#{_1["n"]}=#{_1["total"]}" }.join(" ") }
        end
        flags.concat(tests)
      end
      { "suite" => @s.name, "repo" => @s.cfg["repo"], "ref" => @s.cfg["ref"], "commit" => @prep["base"]["commit"],
        "rails" => @s.r.rails, "ruby" => @s.r.ruby_v, "seeds" => @runs.map { _1["seed"] }.uniq,
        "bumps" => @s.cfg.fetch("bumps", {}), "shims" => @s.inputs["shims"], "lock_diff" => @s.lock_diff,
        "runs" => @runs.map { _1.slice("tree", "n", "seed", "loaded", "total", "status", "secs", "load_errors", "key", "log").merge("failed" => _1["failures"]&.size) },
        "base_only" => base_only, "flags" => flags }
    end

    def fails(t) = by(t).map { _1["failures"] || {} }

    def base_only
      b, c = fails("base"), fails("cand")
      (b.flat_map(&:keys).uniq - c.flat_map(&:keys)).size
    end

    def tests
      b, c = fails("base"), fails("cand")
      alone_n = @s.r.m.fetch("alone_runs", 5)
      c.flat_map(&:keys).uniq.sort.filter_map do |id|
        cf = c.count { _1.key?(id) }
        bf = b.count { _1.key?(id) }
        csig = c.map { _1.dig(id, "signature") }.compact
        bsig = b.map { _1.dig(id, "signature") }.compact
        row = { "test" => id, "desc" => c.find { _1[id] }[id]["desc"], "signature" => csig.first,
                "candidate" => "#{cf}/2", "base" => "#{bf}/2" }
        if bf.positive?
          if (csig.map { Classify.kind(_1) } & bsig.map { Classify.kind(_1) }).any?
            row.merge("class" => "base-failing")
          else
            row.merge("class" => "signature-changed", "detail" => "base: #{bsig.first}")
          end
        elsif cf == 2
          row.merge("class" => "confirmed")
        else
          seed = by("cand").find { fails_in(_1, id) }["seed"]
          Readiness.log "#{@s.name}: #{id} failed under seed #{seed} only; #{alone_n} runs alone per tree"
          ac, ab = @s.alone("cand", id, alone_n), @s.alone("base", id, alone_n)
          alone = "alone: cand #{ac["failed"]}/#{alone_n} failed, base #{ab["failed"]}/#{alone_n} failed" +
            (ac["not_run"] + ab["not_run"]).then { _1.positive? ? ", #{_1} alone runs selected no test" : "" }
          cls = ac["failed"].zero? && ac["not_run"].zero? ? "order-dependent" : "flaky-candidate"
          row.merge("class" => cls, "detail" => "failed under seed #{seed} only; #{alone}")
        end
      end
    end

    def fails_in(run, id) = run["failures"]&.key?(id)
  end

  class Report
    CLASSES = %w[confirmed suite-did-not-load signature-changed flaky-candidate order-dependent test-count-mismatch base-failing].freeze

    def initialize(round, results)
      @r, @results = round, results
    end

    def rows
      @rows ||= @results.flat_map { |s| s["flags"].map { _1.merge("suite" => s["suite"]) } }
                        .sort_by { [CLASSES.index(_1["class"]), _1["signature"].to_s, _1["suite"], _1["test"]] }
    end

    def groups
      rows.group_by { [_1["class"], _1["signature"].to_s] }.map do |(cls, sig), rs|
        { "class" => cls, "signature" => sig, "count" => rs.size, "suites" => rs.map { _1["suite"] }.uniq,
          "tests" => rs.map { _1.except("class", "signature") } }
      end
    end

    def write
      head = { "rails" => @r.rails, "ruby" => @r.ruby_v, "seeds" => @r.m["seeds"], "generated" => Time.now.utc.iso8601 }
      File.write(File.join(@r.out, "flags.json"), JSON.pretty_generate(head.merge(
        "suites" => @results.map { _1.except("flags", "runs").merge("runs" => _1["runs"].map { |x| x.except("log", "key") }) },
        "groups" => groups)))
      cols = %w[class suite test signature candidate base detail]
      tsv = ([cols.join("\t")] + rows.map { |r| cols.map { r[_1].to_s.tr("\t\n", "  ") }.join("\t") }).join("\n") + "\n"
      File.write(File.join(@r.out, "flags.tsv"), tsv)
      File.write(File.join(@r.out, "summary.md"), markdown(head))
      Readiness.log "wrote #{@r.out}/{flags.json,flags.tsv,summary.md}: #{rows.size} rows"
    end

    def markdown(head)
      b, c = head["rails"]["base"], head["rails"]["cand"]
      md = +"# Rails readiness: #{c["ref"]} against #{b["ref"]}\n\n"
      md << "Base `#{b["sha"][0, 10]}` (#{b["version"]}), candidate `#{c["sha"][0, 10]}` (#{c["version"]}), #{head["ruby"].split(" (").first}, " \
            "seeds #{head["seeds"].join(" and ")} (run 1 and run 2 on both trees). Generated #{head["generated"]}.\n\n"
      md << "| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |\n| --- | --- | --- | --- | --- | --- |\n"
      @results.each do |s|
        fmt = ->(t) { s["runs"].select { _1["tree"] == t }.map { |x| x["loaded"] ? "#{x["total"]} / #{x["failed"]}F" : "did not load" }.join(", ") }
        counts = s["flags"].map { _1["class"] }.tally.sort_by { CLASSES.index(_1[0]) }.map { "#{_2} #{_1}" }.join(", ")
        extra = [("bumps: " + s["bumps"].map { |k, v| "#{k} #{v.is_a?(Hash) ? v.values.join(" ") : v}" }.join(", ") if s["bumps"].any?),
                 ("shims: #{s["shims"].size}" if s["shims"].any?)].compact.join("; ")
        md << "| #{s["suite"]}#{extra.empty? ? "" : " (#{extra})"} | `#{s["ref"]}` (`#{s["commit"][0, 10]}`) | #{fmt.("base")} | #{fmt.("cand")} | " \
              "#{counts.empty? ? "–" : counts} | #{Array(s["lock_diff"]).join(", ")} |\n"
      end
      md << "\nRuns read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; " \
            "`flaky-candidate` and `order-dependent` fail under one seed only (then run alone #{@r.m.fetch("alone_runs", 5)} times per tree); " \
            "`base-failing` fails on base too; `signature-changed` fails on both with different errors.\n"
      groups.group_by { _1["class"] }.each do |cls, gs|
        md << "\n## #{cls} (#{gs.sum { _1["count"] }})\n\n| Signature | Count | Suites | Example |\n| --- | --- | --- | --- |\n"
        gs.each do |g|
          ex = g["tests"].first
          note = [ex["test"], ex["detail"]].compact.join("; ")
          md << "| `#{g["signature"].gsub("|", "\\|").gsub("`", "'")}` | #{g["count"]} | #{g["suites"].join(", ")} | #{note.gsub("|", "\\|")[0, 220]} |\n"
        end
      end
      md
    end
  end
end

if $PROGRAM_NAME == __FILE__
  opts = { jobs: 1, fresh: [] }
  OptionParser.new do |o|
    o.banner = "usage: ruby readiness.rb MANIFEST.yml [options]"
    o.on("--work DIR") { opts[:work] = _1 }
    o.on("--out DIR") { opts[:out] = _1 }
    o.on("--only LIST", Array) { opts[:only] = _1 }
    o.on("--jobs N", Integer) { opts[:jobs] = _1 }
    o.on("--fresh LIST", Array, "drop cached state of these suites first") { opts[:fresh] = _1 }
    o.on("--report", "only rewrite the report from cached state") { opts[:report] = true }
  end.parse!
  round = Readiness::Round.new(ARGV.fetch(0), work: opts[:work], out: opts[:out])
  opts[:report] ? round.report : round.run(only: opts[:only], jobs: opts[:jobs], fresh: opts[:fresh])
end
