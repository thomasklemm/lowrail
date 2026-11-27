# frozen_string_literal: true

# ruby app_cg_drive.rb OUT.jsonl APP ROUNDS ARMS MODE "WORKLOAD|WORKLOAD"
# One Callgrind process per (round, arm), arm order rotated by round. ARM main/main2 = Rails 088fc0cf61, fix2 = DT1.
# Each process appends its JSON line plus the instruction counts of its dumps (empty window, then N window per workload).
require "json"
load File.expand_path("~/workspace/repo/script/census")

out, app, rounds, arms, mode, only = ARGV
shas = { "main" => "088fc0cf61e4ba0c7987decafacc69adb3e22eec", "main2" => "088fc0cf61e4ba0c7987decafacc69adb3e22eec",
  "fix2" => "4e635c7ca5aa5e66f51bbf6b1c5b9c9ae3a0ed57", "mainp" => "088fc0cf61e4ba0c7987decafacc69adb3e22eec", "fix3" => "8d672ceec2181ec3da4e79d2ce674ca916cfbeca", "fix4" => "ed506112d92a58ce55711f04301412558d873c7c" }
ruby = File.join(`mise where ruby@4.0.10`.strip, "bin")
dir = Census.app_dir("censusl6rw", app)
vg = File.expand_path("~/w/valgrind-brk512/bin/valgrind")
heap = { "RUBY_GC_HEAP_0_INIT_SLOTS" => "1000000", "RUBY_GC_HEAP_1_INIT_SLOTS" => "250000",
  "RUBY_GC_HEAP_2_INIT_SLOTS" => "100000", "RUBY_GC_HEAP_3_INIT_SLOTS" => "20000", "RUBY_GC_HEAP_4_INIT_SLOTS" => "10000" }
arms = arms.split(",")
Integer(rounds).times do |r|
  arms.rotate(r % arms.size).each do |arm|
    sha = shas.fetch(arm)
    gemfile = File.join(dir, arm == "mainp" ? "Gemfile.census-mainpath" : "Gemfile.census-#{sha[0, 12]}")
    env = Census.env_for(app, ruby, { "sha" => sha }, gemfile).merge(heap).merge("CENSUS_MODE" => mode == "yjit" ? "yjit" : "interpreter",
      "APP" => app, "ARM" => arm, "ONLY" => only, "WARM" => ENV.fetch("WARM", "200"), "N" => ENV.fetch("N", "20"))
    cgout = "/tmp/cg-#{app}-#{arm}-#{r}-#{mode}.%p"
    cmd = ["taskset", "-c", ENV.fetch("CPU", "1"), vg, "--tool=callgrind", "--instr-atstart=no", "--callgrind-out-file=#{cgout}",
      "--log-file=/tmp/cg-#{app}-#{arm}-#{r}-#{mode}.vg.log", File.join(ruby, "ruby"), *(mode == "yjit" ? ["--yjit"] : []),
      "-I", File.expand_path("~/w/cgext-4010"), "-rbundler/setup", File.join(__dir__, "app_cg.rb")]
    line = IO.popen(env, cmd, chdir: dir, err: ["/tmp/cg-#{app}.err", "a"], &:read).lines.last
    unless $?.success? && line&.start_with?("{")
      warn "failed: #{arm} round #{r} (skipped)"
      next
    end
    j = JSON.parse(line)
    dumps = Dir["/tmp/cg-#{app}-#{arm}-#{r}-#{mode}.*"].grep(/\.\d+\.\d+\z/).sort_by { _1.split(".").last.to_i }
    j["ir"] = dumps.map { |f| File.foreach(f).grep(/\A(summary|totals): /).first.split[1].to_i }
    dumps.each { File.delete(_1) } unless ENV["KEEP"]
    j["round"] = r
    j["mode"] = mode
    File.open(out, "a") { _1.puts JSON.generate(j) }
    warn "round #{r} #{mode} #{arm}: #{j["ir"].inspect}"
  end
end
