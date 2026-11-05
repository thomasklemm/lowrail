# frozen_string_literal: true

# Rails readiness runner (docs/upstream/readiness.md). Runs each suite of a manifest on a base and a candidate
# Rails tree, once per seed, through the ecosystem harness (../ecosystem/eco.sh, Gemfile.eco), and flags what fails
# only on the candidate. Every run is cached under WORK/state, keyed by its inputs, so a restart resumes. Flags are
# matched against known.yml.
#
#   ruby readiness.rb MANIFEST.yml [--work DIR] [--out DIR] [--only a,b] [--jobs N] [--fresh a,b] [--report] [--check]
#                                  [--services-down]
require "digest"
require "fileutils"
require "time"
require "json"
require "open3"
require "optparse"
require "shellwords"
require "yaml"
require_relative "services"

module Readiness
  HERE = __dir__
  ECO = File.expand_path("../ecosystem", HERE)
  ROOT = File.expand_path("../../..", HERE)
  RECORDS = "https://github.com/thomasklemm/lowrail/blob/main/"
  TREES = %w[base cand].freeze
  LOCK = Mutex.new
  PREP = Mutex.new
  # Suites that use the same database service, or name the same `exclusive` (a fixed tmp path, say), run one at a time.
  SERVICE_LOCKS = Hash.new { |h, k| h[k] = Mutex.new }.tap { |h| Services::NAMES.each { h[_1] } }

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
    attr_reader :m, :work, :out, :seeds, :path

    def initialize(path, work: nil, out: nil)
      @path = File.expand_path(path)
      @m = YAML.safe_load_file(@path, aliases: true)
      name = File.basename(path, ".*")
      @work = File.expand_path(work || "~/src/readiness/#{name}")
      @out = File.expand_path(out || File.join(@work, "out"))
      @seeds = m.fetch("seeds")
      @trees, @ruby_v = {}, {}
      FileUtils.mkdir_p([@work, @out])
    end

    def ruby = m.fetch("ruby")
    def ruby_v(ver = ruby) = @ruby_v[ver] ||= `mise exec ruby@#{ver} -- ruby -v`.strip
    def suites = m.fetch("suites")
    def repo = m.dig("rails", "repo") || "https://github.com/rails/rails"
    def rails_ref(t) = m.dig("rails", t == "base" ? "base" : "candidate")

    # The round's default trees live in WORK/rails-base and WORK/rails-cand; a suite that pins other Rails refs
    # gets WORK/rails-<sha>.
    def tree(ref, default = nil)
      @trees[[ref, default]] ||= begin
        clone = File.join(work, "rails.git")
        commit = Readiness.fetch(clone, repo, ref)
        dir = File.join(work, "rails-#{default || commit[0, 12]}")
        Readiness.checkout(clone, repo, commit, dir)
        { "ref" => ref, "sha" => commit, "version" => File.read(File.join(dir, "RAILS_VERSION")).strip, "dir" => dir }
      end
    end

    def rails = TREES.to_h { |t| [t, tree(rails_ref(t), t)] }

    def suite(name) = Suite.new(self, name, suites.fetch(name))

    def run(only: nil, jobs: 1, fresh: [])
      names = only || suites.keys
      fresh.each { |n| FileUtils.rm_rf(File.join(work, "state", n)) }
      rails
      names.each { |n| s = suite(n); s.rails; ruby_v(s.ruby); s.locks }
      needed = names.flat_map { suites[_1].fetch("services", []) }.uniq
      running = needed.select { Services.listening?(Services::PORTS.fetch(_1)) }
      Services.up(needed, work)
      queue = Queue.new
      names.each { queue << _1 }
      queue.close
      Array.new(jobs) do
        Thread.new do
          while (name = queue.pop)
            begin
              suite(name).call
            rescue => e
              Readiness.log "#{name}: runner error #{e.class}: #{e.message}"
              suite(name).write_error(e)
            end
          end
        end
      end.each(&:join)
      report
    ensure
      Services.down(needed - running) if needed
    end

    def report
      results = suites.keys.filter_map { |n| f = File.join(work, "state", n, "suite.json"); JSON.parse(File.read(f)) if File.exist?(f) }
        .select { |r| r["rails"].transform_values { _1["sha"] } == rails.transform_values { _1["sha"] } || suites.dig(r["suite"], "rails") }
      Report.new(self, results, Known.load(self)).write
    end

    def check(resolve: true) = Check.new(self).call(resolve:)
  end

  class Suite
    attr_reader :name, :cfg, :r

    def initialize(round, name, cfg)
      @r, @name, @cfg = round, name, cfg
      @state = File.join(round.work, "state", name)
      FileUtils.mkdir_p(@state)
    end

    def framework = @cfg.fetch("framework")
    def ruby = @cfg.fetch("ruby", @r.ruby).to_s
    def ruby_v = @r.ruby_v(ruby)
    def clone = File.join(@r.work, "suites", "#{@name}.git")
    def dir(t) = File.join(@r.work, "suites", @name, t)
    def gemfile = @cfg.fetch("gemfile", "Gemfile")
    def eco_lock(t) = File.join(dir(t), File.dirname(gemfile), "Gemfile.eco-#{t}.lock")

    def rails
      @rails ||= TREES.to_h do |t|
        ref = @cfg.dig("rails", t == "base" ? "base" : "candidate")
        [t, ref ? @r.tree(ref) : @r.tree(@r.rails_ref(t), t)]
      end
    end

    # eco.sh takes Rails from ECO_ROOT/rails-LABEL; a suite with its own Rails pins gets its own root of symlinks.
    def eco_root
      return @r.work if rails.all? { |t, tr| tr["dir"] == File.join(@r.work, "rails-#{t}") }
      root = File.join(@r.work, "roots", @name)
      FileUtils.mkdir_p(root)
      TREES.each { |t| l = File.join(root, "rails-#{t}"); FileUtils.rm_f(l); File.symlink(rails[t]["dir"], l) }
      root
    end

    def env(t, extra = {})
      { "ECO_ROOT" => eco_root, "ECO_RUBY" => ruby, "ECO_GEMFILE" => gemfile, "BUNDLE_PATH" => File.join(@r.work, "bundle", File.basename(@cfg.fetch("repo"), ".git")),
        "ECO_BUMPS" => @cfg.fetch("bumps", {}).inspect }.merge(@cfg.fetch("env", {}).transform_values(&:to_s)).merge(extra)
    end

    def eco(t, cmd) = "#{File.join(ECO, "eco.sh").shellescape} #{dir(t).shellescape} #{t} bash -c #{cmd.shellescape}"

    def shims = @cfg.fetch("shims", []).map { _1.is_a?(Hash) ? _1 : { "run" => _1 } }

    def patch_path(s) = File.expand_path(s["patch"], File.dirname(@r.path))

    # Explicit inputs: everything that is not Rails, Ruby, the lock or the seed but changes the result.
    def inputs
      sh = shims.map { |s| s["patch"] ? s.merge("sha" => Readiness.sha(File.read(patch_path(s)))) : s }
      @cfg.slice("repo", "framework", "gemfile", "lock", "env", "bumps", "setup", "test", "single").merge("shims" => sh)
    end

    def call
      locks.reverse.inject(-> { call_locked }) { |inner, l| -> { l.synchronize(&inner) } }.call
    end

    def locks = (@cfg.fetch("services", []) + Array(@cfg["exclusive"])).uniq.sort.map { SERVICE_LOCKS[_1] }

    def call_locked
      t0 = Time.now
      FileUtils.rm_f(File.join(@state, "suite.json"))
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

    # A suite the runner itself failed on still appears in the report, as not loaded.
    def write_error(e)
      flag = { "class" => "suite-did-not-load", "test" => "(suite)", "signature" => "runner error: #{e.class}: #{e.message}"[0, 200], "detail" => "runner error" }
      File.write(File.join(@state, "suite.json"), JSON.pretty_generate(
        "suite" => @name, "repo" => @cfg["repo"], "ref" => @cfg["ref"], "commit" => @commit.to_s, "rails" => rails.transform_values { _1.except("dir") },
        "ruby" => ruby_v, "seeds" => @r.seeds, "bumps" => @cfg.fetch("bumps", {}), "shims" => inputs["shims"], "lock_diff" => nil,
        "runs" => [], "base_only" => 0, "flags" => [flag]))
    end

    def prep_key(t)
      base_lock = t == "cand" ? JSON.parse(File.read(File.join(@state, "prepare-base.json")))["lock_sha"] : nil
      Readiness.sha([@name, @commit, rails[t]["sha"], ruby_v, inputs, base_lock])
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
      Readiness.log "#{@name}: preparing #{t} (Rails #{rails[t]["sha"][0, 10]})"
      commit = Readiness.checkout(clone, @cfg.fetch("repo"), @commit, dir(t))
      log = File.join(@state, "prepare-#{t}.log")
      File.write(log, "")
      seed_lock(t)
      steps = shims.select { _1.fetch("tree", t) == t }.map { |s| s["patch"] ? "git apply #{patch_path(s).shellescape}" : s.fetch("run") }
      res = { "key" => key, "commit" => commit, "ok" => true }
      begin
        steps.each { |s| Readiness.sh!(s, chdir: dir(t), env: env(t), out: log) }
        Readiness.sh!(eco(t, "ruby -v"), chdir: dir(t), env: env(t), out: log)
        @cfg.fetch("setup", []).each { |s| Readiness.sh!(eco(t, s), chdir: dir(t), env: env(t), out: log) }
      rescue RuntimeError => e
        res.merge!("ok" => false, "signature" => "#{Parse.crash_signature(File.read(log), self) || e.message} (prepare)")
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
      key = Readiness.sha([@name, prep["commit"], rails[t]["sha"], prep["lock_sha"], ruby_v, seed, inputs])
      f = File.join(@state, "run-#{t}-#{n}-#{key[0, 12]}.json")
      return JSON.parse(File.read(f)) if File.exist?(f)
      Readiness.log "#{@name}: #{t} run #{n} (seed #{seed})"
      res = execute(t, @cfg.fetch("test"), seed, f.sub(/\.json\z/, ""))
      res.merge!("tree" => t, "n" => n, "seed" => seed, "key" => key)
      File.write(f, JSON.generate(res))
      res
    end

    def execute(t, cmd, seed, stem, extra_testopts: "")
      log, json = "#{stem}.log", "#{stem}.rspec"
      FileUtils.rm_rf([log, json])
      e = env(t, seed_env(seed, extra_testopts))
      if framework == "rspec"
        e["READINESS_RSPEC_DIR"] = json
        e["SPEC_OPTS"] = "--seed #{seed} --require #{File.join(HERE, "rspec_json.rb")} --format progress --format LowrailReadinessJSON"
      elsif framework == "cucumber"
        e["CUCUMBER_OPTS"] = "--order random:#{seed} --format pretty --no-color"
      elsif framework == "test-unit"
        e["TESTOPTS"] = "--order=random #{extra_testopts}".strip
        e["RUBYOPT"] = "-r#{File.join(HERE, "test_unit_seed.rb")} #{e["RUBYOPT"]}".strip
      end
      timeout = @r.m.fetch("timeout", 3600)
      t0 = Time.now
      system(e, "timeout --kill-after=30 #{timeout} #{eco(t, cmd)}", chdir: dir(t), out: log, err: [:child, :out])
      status = $?.exitstatus
      res = Parse.call(framework, log, json, self).merge("status" => status, "secs" => (Time.now - t0).round, "log" => log)
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
        elsif framework == "cucumber"
          execute(t, (@cfg["single"] || "cucumber $CUCUMBER_OPTS {id}").gsub("{id}", test.shellescape), seed, stem)
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
      [@name, p["commit"], rails[t]["sha"], p["lock_sha"], ruby_v, inputs]
    end

    def lock_diff
      return nil unless File.exist?(eco_lock("base")) && File.exist?(eco_lock("cand"))
      o, = Open3.capture2({ "BUNDLE_GEMFILE" => eco_lock("cand").delete_suffix(".lock") }, "mise", "exec", "ruby@#{ruby}", "--", "ruby",
        File.join(ECO, "eco-locks.rb"), eco_lock("base"), eco_lock("cand"), chdir: dir("cand"))
      o.lines.map(&:strip)
    end
  end

  module Parse
    module_function

    EXC = /\A([A-Z]\w*(?:::[A-Z]\w*)*):?\z/

    # Strip what differs between trees and runs but not between causes: object addresses, tmp paths, the
    # checkout and gem locations, line numbers inside Rails, the two Rails version strings.
    def norm(s, suite)
      work = Regexp.escape(suite.r.work)
      s = s.to_s.dup
      s.gsub!(%r{#{work}/(?:roots/[^/]+/)?rails-[\w]+/(\S+?\.rb):\d+}, 'RAILS/\1')
      s.gsub!(%r{#{work}/(?:roots/[^/]+/)?rails-[\w]+/}, "RAILS/")
      s.gsub!(%r{#{work}/suites/[^/]+/(?:base|cand)/}, "")
      s.gsub!(%r{/\S*?/gems/(?:ruby/)?[\d.]+/(?:bundler/)?gems/}, "GEMS/")
      s.gsub!(%r{/\S*?/lib/ruby/[\d.]+/}, "RUBYLIB/")
      suite.rails.each_value { |r| s.gsub!(r["version"], "RAILS_VERSION") }
      s.gsub!(/0x\h+/, "0xX")
      s.gsub!(%r{/tmp/[^\s:'",)\]]+}, "/tmp/X")
      s.gsub!(/\d+(?:\.\d+)? ?(?:ms|seconds|s)\b/, "Ns")
      s.gsub(/\s+/, " ").strip[0, 200]
    end

    def call(framework, log, json_dir, suite)
      text = File.exist?(log) ? File.binread(log).force_encoding("UTF-8").scrub : ""
      res = case framework
            when "rspec" then rspec(json_dir, suite)
            when "cucumber" then cucumber(text, suite)
            else minitest(text, suite) # minitest and test-unit
            end
      res["signature"] ||= crash_signature(text, suite) || "no test totals in output" unless res["loaded"]
      res
    end

    # One JSON file per RSpec process (rspec_json.rb); examples, counts and load errors are summed. A process can
    # write several (rspec-rails' sandboxed configurations attach the formatter again); its largest one counts.
    def rspec(json_dir, suite)
      files = Dir[File.join(json_dir, "*.json")].group_by { File.basename(_1)[/\A\d+/] }.filter_map do |_pid, fs|
        fs.filter_map { JSON.parse(File.read(_1)) rescue nil }.max_by { _1.dig("summary", "example_count").to_i }
      end
      return { "loaded" => false, "total" => 0, "failures" => {} } if files.empty?
      examples = files.flat_map { _1["examples"].to_a }
      fails = examples.select { _1["status"] == "failed" }.to_h do |ex|
        e = ex["exception"] || {}
        [ex["id"], { "signature" => norm("#{e["class"]}: #{e["message"].to_s.lines.reject { _1.strip.empty? }.first}", suite), "desc" => ex["full_description"].to_s[0, 160] }]
      end
      outside = files.flat_map { _1["messages"].to_a }.select { _1.include?("An error occurred") }.to_h do |msg|
        where = msg[/An error occurred (?:while loading (\S+?)\.?$|in (.+?)\.$)/, 1] || msg[/An error occurred in (.+?)\./, 1] || "outside examples"
        ["load: #{where}", { "signature" => outside_signature(msg, suite), "desc" => "error outside examples" }]
      end
      total = files.sum { _1.dig("summary", "example_count").to_i }
      errors = files.sum { _1.dig("summary", "errors_outside_of_examples_count").to_i }
      res = { "loaded" => true, "total" => total, "failures" => fails.merge(outside) }
      if total.zero? && (outside.any? || errors.positive?)
        res.merge!("loaded" => false, "signature" => outside.values.map { _1["signature"] }.tally.max_by(&:last)&.first)
        res["load_errors"] = outside.size
      end
      res
    end

    def outside_signature(msg, suite)
      lines = msg.lines.map(&:rstrip)
      i = lines.index { _1.strip.match?(EXC) && !_1.strip.start_with?("Failure/Error") }
      return norm(lines.reject(&:empty?)[1], suite) unless i
      norm("#{lines[i].strip.chomp(":")}: #{lines[(i + 1)..].find { !_1.strip.empty? }&.strip}", suite)
    end

    def minitest(text, suite)
      lines = text.lines
      totals = lines.grep(/^\d+ (?:runs|tests), \d+ assertions/)
      return { "loaded" => false, "total" => 0, "failures" => {} } if totals.empty?
      fails = {}
      lines.each do |l|
        next unless l =~ /^(Failure|Error): (test\S*)\(([\w:]+)\)(?: \[[^\]]*\])?:?\s*(.*)$/ # test-unit
        msg = $4.empty? ? "Test::Unit::AssertionFailedError" : $4
        fails["#{$3}##{$2}"] ||= { "signature" => norm($1 == "Error" ? msg : "Test::Unit::AssertionFailedError: #{msg}", suite), "desc" => "#{$3}##{$2}" }
      end
      lines.each_with_index do |l, i|
        next unless l =~ /^\s*(?:\d+\) )?(Failure|Error):\s*$/
        kind = $1
        id = lines[i + 1].to_s.strip.sub(/ \[.*\]:?\z/, "").sub(/:\z/, "")
        msg = lines[(i + 2)..].to_a.find { !_1.strip.empty? }.to_s.strip
        sig = kind == "Error" ? msg : "Minitest::Assertion: #{msg}"
        fails[id] ||= { "signature" => norm(sig, suite), "desc" => id }
      end
      { "loaded" => true, "total" => totals.sum { _1[/\d+/].to_i }, "failures" => fails }
    end

    # Cucumber's pretty output (CUCUMBER_OPTS): totals from "N scenarios (…)", failures from the "Failing
    # Scenarios" list, each signed with the first "message (Class)" line inside its scenario.
    def cucumber(text, suite)
      lines = text.lines
      totals = lines.grep(/^\d+ scenarios? \(/)
      return { "loaded" => false, "total" => 0, "failures" => {} } if totals.empty?
      fails = lines.filter_map { _1[/^cucumber (?:-p \S+ )?(\S+:\d+) #/, 1] }.uniq.to_h do |loc|
        start = lines.index { _1 =~ /^\s*(?:Scenario|Example|Scenario Outline):.*# #{Regexp.escape(loc)}\s*$/ }
        block = start ? lines[(start + 1)..].take_while { _1 !~ /^\s*(?:Scenario|Example|Scenario Outline|Feature|Background|Rule):/ } : []
        line = block.find { _1 =~ /\(([A-Z]\w*(?:::\w+)*)\)\s*$/ }
        msg = line.to_s.sub(/\s*\([A-Z]\w*(?:::\w+)*\)\s*$/, "").strip.delete_prefix("+").sub(/\A\S*:\d+:in [^:]*: /, "")
        sig = line ? "#{line[/\(([A-Z]\w*(?:::\w+)*)\)\s*$/, 1]}: #{msg}" : "failed (no message found)"
        [loc, { "signature" => norm(sig, suite), "desc" => lines[start].to_s.strip.sub(/\s*#.*\z/, "")[0, 160] }]
      end
      { "loaded" => true, "total" => totals.sum { _1[/\d+/].to_i }, "failures" => fails }
    end

    # The exception that stopped a process before any test ran: Ruby's "file:line:in 'm': msg (Class)",
    # a Bundler resolution error, or nil.
    def crash_signature(text, suite)
      if (l = text.lines.reverse.find { _1 =~ /:in .*: .+ \(([A-Z]\w*(?:::\w+)*)\)$/ })
        cls = l[/\(([A-Z]\w*(?:::\w+)*)\)$/, 1]
        msg = l.sub(/\A.*?:in [^:]*: /, "").sub(/ \(#{Regexp.escape(cls)}\)\s*\z/, "")
        return norm("#{cls}: #{msg}", suite)
      end
      if (l = text.lines.reverse.find { _1 =~ /\A([A-Z]\w*(?:::\w+)*): .+ \(\1\)$/ })
        return norm(l.sub(/ \([A-Z]\w*(?:::\w+)*\)\s*\z/, ""), suite)
      end
      l = text.lines.find { _1 =~ /Could not find|could not find compatible|Bundler could not|Gem::MissingSpec|LoadError|NameError/ }
      l && norm(l, suite)
    end
  end

  # Turns four runs (base and candidate, seeds A and B) into flags.
  class Classify
    # Assertion messages embed the values under test, so two assertion failures count as the same error;
    # RSpec wraps an assertion plus later hook errors in MultipleExceptionError.
    ASSERTION = /\A(?:RSpec::Expectations::ExpectationNotMetError|RSpec::Core::MultipleExceptionError|Minitest::Assertion|Test::Unit::AssertionFailedError):/

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
        "rails" => @s.rails.transform_values { _1.except("dir") }, "ruby" => @s.ruby_v, "seeds" => @runs.map { _1["seed"] }.uniq,
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

  # Known findings (known.yml): a flag matches the first entry whose suite, signature and optional test and class
  # patterns match it.
  class Known
    STATUSES = %w[open-pr merged prepared issue record-only gem-side noise].freeze
    KEYS = %w[id suite signature test class status record note checked].freeze

    def self.load(round)
      path = File.expand_path(round.m.fetch("known", File.join(HERE, "known.yml")), File.dirname(round.path))
      new(File.exist?(path) ? YAML.safe_load_file(path).fetch("findings") : [])
    end

    attr_reader :entries

    def initialize(entries)
      @entries = entries
      @rx = entries.map do |e|
        { suite: /\A(?:#{e.fetch("suite")})\z/, signature: Regexp.new(e.fetch("signature")), test: e["test"] && Regexp.new(e["test"]) }
      end
    end

    def match(row)
      i = @entries.each_index.find do |k|
        e, rx = @entries[k], @rx[k]
        rx[:suite].match?(row["suite"]) && rx[:signature].match?(row["signature"].to_s) &&
          (!rx[:test] || rx[:test].match?(row["test"].to_s)) && (!e["class"] || Array(e["class"]).include?(row["class"]))
      end
      i ? @entries[i] : nil
    end

    def problems
      @entries.flat_map do |e|
        out = []
        out << "#{e["id"]}: unknown keys #{(e.keys - KEYS).join(", ")}" if (e.keys - KEYS).any?
        out << "#{e["id"]}: missing #{(%w[id suite signature status record] - e.keys).join(", ")}" if (%w[id suite signature status record] - e.keys).any?
        out << "#{e["id"]}: status #{e["status"]} not in #{STATUSES.join(", ")}" unless STATUSES.include?(e["status"])
        out << "#{e["id"]}: class #{e["class"]} unknown" if e["class"] && (Array(e["class"]) - Report::CLASSES).any?
        out << "#{e["id"]}: record #{e["record"]} not found" unless File.exist?(File.join(ROOT, e["record"].to_s.sub(/#.*/, "")))
        out
      end + @entries.group_by { _1["id"] }.filter_map { |id, es| "#{id}: entries disagree on status or record" if es.map { _1.values_at("status", "record") }.uniq.size > 1 }
    end
  end

  class Report
    CLASSES = %w[confirmed suite-did-not-load signature-changed flaky-candidate order-dependent test-count-mismatch base-failing].freeze

    def initialize(round, results, known)
      @r, @results, @known = round, results, known
    end

    def rows
      @rows ||= @results.flat_map { |s| s["flags"].map { _1.merge("suite" => s["suite"]) } }
                        .map { |row| e = @known.match(row); row.merge("match" => e ? "known:#{e["id"]}" : "new") }
                        .sort_by { [_1["match"] == "new" ? 0 : 1, CLASSES.index(_1["class"]), _1["signature"].to_s, _1["suite"], _1["test"]] }
    end

    def groups(rs = rows)
      rs.group_by { [_1["class"], _1["signature"].to_s] }.map do |(cls, sig), g|
        { "class" => cls, "signature" => sig, "count" => g.size, "suites" => g.map { _1["suite"] }.uniq,
          "match" => g.map { _1["match"] }.uniq, "tests" => g.map { _1.except("class", "signature") } }
      end
    end

    def write
      head = { "rails" => @r.rails.transform_values { _1.except("dir") }, "ruby" => @r.ruby_v, "seeds" => @r.m["seeds"], "generated" => Time.now.utc.iso8601 }
      File.write(File.join(@r.out, "flags.json"), JSON.pretty_generate(head.merge(
        "suites" => @results.map { _1.except("flags", "runs").merge("runs" => _1["runs"].map { |x| x.except("log", "key") }) },
        "groups" => groups)))
      cols = %w[match class suite test signature candidate base detail]
      tsv = ([cols.join("\t")] + rows.map { |r| cols.map { r[_1].to_s.tr("\t\n", "  ") }.join("\t") }).join("\n") + "\n"
      File.write(File.join(@r.out, "flags.tsv"), tsv)
      File.write(File.join(@r.out, "summary.md"), markdown(head))
      Readiness.log "wrote #{@r.out}/{flags.json,flags.tsv,summary.md}: #{rows.size} rows, #{rows.count { _1["match"] == "new" }} new"
    end

    def cell(s) = s.to_s.gsub("|", "\\|").gsub("`", "'")

    def class_tables(rs)
      groups(rs).group_by { _1["class"] }.map do |cls, gs|
        t = +"\n### #{cls} (#{gs.sum { _1["count"] }})\n\n| Signature | Count | Suites | Example |\n| --- | --- | --- | --- |\n"
        gs.each do |g|
          ex = g["tests"].first
          note = [ex["test"], ex["detail"]].compact.join("; ")
          t << "| `#{cell(g["signature"])}` | #{g["count"]} | #{g["suites"].join(", ")} | #{cell(note)[0, 220]} |\n"
        end
        t
      end.join
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
        own = [("Rails #{s["rails"]["base"]["sha"][0, 10]} → #{s["rails"]["cand"]["sha"][0, 10]}" if s["rails"] != head["rails"]),
               (s["ruby"].split(" (").first if s["ruby"] != head["ruby"])].compact
        extra = own + [("bumps: " + s["bumps"].map { |k, v| "#{k} #{v.is_a?(Hash) ? v.values.join(" ") : v}" }.join(", ") if s["bumps"].any?),
                       ("shims: #{s["shims"].size}" if s["shims"].any?)].compact
        md << "| #{s["suite"]}#{extra.empty? ? "" : " (#{extra.join("; ")})"} | `#{s["ref"]}` (`#{s["commit"][0, 10]}`) | #{fmt.("base")} | #{fmt.("cand")} | " \
              "#{counts.empty? ? "–" : counts} | #{Array(s["lock_diff"]).join(", ")} |\n"
      end
      md << "\nRuns read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; " \
            "`flaky-candidate` and `order-dependent` fail under one seed only (then run alone #{@r.m.fetch("alone_runs", 5)} times per tree); " \
            "`base-failing` fails on base too; `signature-changed` fails on both with different errors. " \
            "Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.\n"
      fresh = rows.select { _1["match"] == "new" && _1["class"] != "base-failing" }
      known = rows.select { _1["match"] != "new" && _1["class"] != "base-failing" }
      md << "\n## New (#{fresh.size})\n"
      md << (fresh.empty? ? "\nNone: every candidate flag matches a known finding.\n" : class_tables(fresh))
      md << "\n## Known (#{known.size})\n"
      unless known.empty?
        md << "\n| Finding | Status | Classes | Count | Suites | Record |\n| --- | --- | --- | --- | --- | --- |\n"
        known.group_by { _1["match"] }.each do |m, rs|
          e = @known.entries.find { "known:#{_1["id"]}" == m }
          md << "| #{e["id"]} | #{e["status"]} | #{rs.map { _1["class"] }.tally.map { "#{_2} #{_1}" }.join(", ")} | #{rs.size} | " \
                "#{rs.map { _1["suite"] }.uniq.join(", ")} | [#{e["record"].sub(%r{\Adocs/upstream/}, "")}](#{RECORDS}#{e["record"]}) |\n"
        end
      end
      base = rows.select { _1["class"] == "base-failing" }
      md << "\n## Fails on base too (#{base.size})\n\n| Signature | Count | Suites | Match |\n| --- | --- | --- | --- |\n" unless base.empty?
      groups(base).each { |g| md << "| `#{cell(g["signature"])}` | #{g["count"]} | #{g["suites"].join(", ")} | #{g["match"].join(", ")} |\n" }
      md
    end
  end

  # --check: the manifest's keys and shapes, its patch files, the known findings, and (with refs) that every
  # Rails and suite ref resolves.
  class Check
    TOP = %w[ruby rails seeds alone_runs timeout suites known].freeze
    SUITE = %w[repo ref framework test setup env gemfile lock shims bumps single ruby rails services exclusive].freeze

    def initialize(round)
      @r = round
    end

    def call(resolve:)
      m = @r.m
      p = []
      p << "unknown top-level keys #{(m.keys - TOP).join(", ")}" if (m.keys - TOP).any?
      p << "seeds: give two (A for run 1, B for run 2)" unless m["seeds"].is_a?(Array) && m["seeds"].size == 2 && m["seeds"].all? { _1.is_a?(Integer) && _1 < 0xFFFF }
      p << "rails: base and candidate required" unless m.dig("rails", "base") && m.dig("rails", "candidate")
      p << "ruby required" unless m["ruby"]
      m.fetch("suites", {}).each { |name, cfg| p.concat(suite(name, cfg).map { "#{name}: #{_1}" }) }
      p.concat(Known.load(@r).problems.map { "known: #{_1}" })
      rubies = ([m["ruby"]] + m.fetch("suites", {}).values.filter_map { _1["ruby"] }).compact.map(&:to_s).uniq
      rubies.each { |v| warn "#{@r.path}: warning: ruby #{v} is not installed (mise install ruby@#{v})" unless system("mise", "where", "ruby@#{v}", out: File::NULL, err: File::NULL) }
      if resolve && p.empty?
        refs = [@r.rails_ref("base"), @r.rails_ref("cand")] + m["suites"].values.flat_map { [_1.dig("rails", "base"), _1.dig("rails", "candidate")] }.compact
        refs.uniq.each { |ref| Readiness.fetch(File.join(@r.work, "rails.git"), @r.repo, ref.to_s) rescue p << "rails ref #{ref} does not resolve" }
        m["suites"].each do |name, cfg|
          s = @r.suite(name)
          Readiness.fetch(s.clone, cfg["repo"], cfg["ref"].to_s)
        rescue RuntimeError
          p << "#{name}: ref #{cfg["ref"]} does not resolve in #{cfg["repo"]}"
        end
      end
      p
    end

    def suite(name, cfg)
      p = []
      return ["not a mapping"] unless cfg.is_a?(Hash)
      p << "unknown keys #{(cfg.keys - SUITE).join(", ")}" if (cfg.keys - SUITE).any?
      %w[repo ref framework test].each { |k| p << "#{k} required" unless cfg[k] }
      p << "framework must be rspec, minitest, test-unit or cucumber" unless %w[rspec minitest test-unit cucumber].include?(cfg["framework"])
      Array(cfg["services"]).each { |n| p << "unknown service #{n} (#{Services::NAMES.join(", ")})" unless Services::NAMES.include?(n) }
      p << "setup must be a list of commands" unless cfg.fetch("setup", []).is_a?(Array)
      p << "env must be a mapping" unless cfg.fetch("env", {}).is_a?(Hash)
      Array(cfg["shims"]).each do |s|
        next if s.is_a?(String)
        p << "shim #{s.inspect}: give run or patch" unless s.is_a?(Hash) && (s.key?("run") ^ s.key?("patch")) && (s.keys - %w[run patch tree]).empty?
        p << "shim tree must be base or cand" if s.is_a?(Hash) && s["tree"] && !TREES.include?(s["tree"])
        p << "patch #{s["patch"]} not found" if s.is_a?(Hash) && s["patch"] && !File.exist?(File.expand_path(s["patch"], File.dirname(@r.path)))
      end
      cfg.fetch("bumps", {}).each { |g, v| p << "bump #{g}: give a version string or {git:, ref:}" unless v.is_a?(String) || (v.is_a?(Hash) && v.any?) }
      p
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
    o.on("--check", "validate the manifest and known.yml and resolve every ref; runs nothing") { opts[:check] = true }
    o.on("--no-resolve", "with --check: skip resolving refs") { opts[:no_resolve] = true }
    o.on("--services-down", "stop every readiness database service (teardown after a crash)") { opts[:down] = true }
  end.parse!
  if opts[:down]
    Readiness::Services.down
    exit
  end
  round = Readiness::Round.new(ARGV.fetch(0), work: opts[:work], out: opts[:out])
  if opts[:check]
    problems = round.check(resolve: !opts[:no_resolve])
    puts problems.empty? ? "#{ARGV[0]}: ok (#{round.suites.size} suites)" : problems.map { "#{ARGV[0]}: #{_1}" }
    exit(problems.empty? ? 0 : 1)
  end
  opts[:report] ? round.report : round.run(only: opts[:only], jobs: opts[:jobs], fresh: opts[:fresh])
end
