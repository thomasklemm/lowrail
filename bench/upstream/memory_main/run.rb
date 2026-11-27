# frozen_string_literal: true

# Memory runs over census copies (script/census setup --corpus CORPUS):
#   ruby run.rb --out DIR --ruby NAME=BIN --rails NAME=SHA --apps LIST --modes interp,zjit [--detail] [--reps 2]
#     [--corpus census-mem] [--jobs 4]
# --ruby and --rails repeat. Each configuration (app, Ruby, mode, Rails) runs
# mem.rb in its own process; repetitions run in ABBA order over the Rails trees
# (A B B A for two trees), so each tree has an A/A pair taken at both ends.
# --detail runs once per configuration with allocation tracing and heap dumps,
# aggregates the dumps with dump.rb and deletes them. One app copy never runs
# two processes at once (they share its database).
require "optparse"
load File.expand_path("../../../script/census", __dir__)

opts = { rubies: {}, rails: {}, modes: %w[interpreter], reps: 2, corpus: "census-mem", jobs: 4 }
OptionParser.new do |o|
  o.on("--out DIR") { opts[:out] = File.expand_path(_1) }
  o.on("--ruby NAME=BIN") { |v| k, b = v.split("=", 2); opts[:rubies][k] = Census.ruby_bin(b) }
  o.on("--rails NAME=SHA") { |v| k, s = v.split("=", 2); opts[:rails][k] = Census.resolve_rails(s) }
  o.on("--apps LIST") { opts[:apps] = _1.split(",") }
  o.on("--modes LIST") { |v| opts[:modes] = v.split(",").map { Census::MODES.fetch(_1) } }
  o.on("--reps N", Integer) { opts[:reps] = _1 }
  o.on("--corpus NAME") { opts[:corpus] = _1 }
  o.on("--jobs N", Integer) { opts[:jobs] = _1 }
  o.on("--detail") { opts[:detail] = true }
  # A copy's own database clone (createdb -T), so configurations of an app
  # that rewrites its fixtures at start (Sure's API key) run side by side.
  o.on("--env KEY=VALUE") { |v| (opts[:env] ||= {}).store(*v.split("=", 2)) }
end.parse!

HERE = __dir__
# Workloads that create rows a measured page lists, so later requests render
# more and more: left out of the request mix.
SKIP = { "writebook" => ["POST page (turbo_stream)"], "sure" => ["POST api transaction"] }.freeze

Census.check_services(opts[:apps])
trees = opts[:rails].keys
order = opts[:detail] ? trees : Array.new(opts[:reps]) { |i| i.even? ? trees : trees.reverse }.flatten
gemfiles = {}
opts[:apps].product(opts[:rubies].to_a, trees).each do |app, (_, bin), tree|
  gemfiles[[app, bin, tree]] = Census.variant(opts[:corpus], app, opts[:rails][tree], bin)
end

jobs = Queue.new
opts[:apps].each do |app|
  runs = opts[:rubies].flat_map do |rname, bin|
    opts[:modes].flat_map do |mode|
      seen = Hash.new(0)
      order.map { |tree| [app, rname, bin, mode, tree, seen[tree] += 1] }
    end
  end
  jobs << runs
end
failed = Queue.new
Array.new([opts[:jobs], opts[:apps].size].min) do
  Thread.new do
    while (runs = (jobs.pop(true) rescue nil))
      runs.each do |app, rname, bin, mode, tree, rep|
        kind = opts[:detail] ? "detail" : "rep#{rep}"
        dir = File.join(opts[:out], "#{rname}-#{mode}", tree)
        FileUtils.mkdir_p(dir)
        out = File.join(dir, "#{app}-#{kind}.jsonl")
        next if File.exist?(out) && File.read(out).include?('"done"')
        File.delete(out) if File.exist?(out)
        rails = opts[:rails][tree]
        env = Census.env_for(app, bin, rails, gemfiles[[app, bin, tree]])
          .merge("CENSUS_MODE" => mode, "MEM_SKIP" => SKIP.fetch(app, []).join("|")).merge(opts.fetch(:env, {}))
        dumps = File.join("/tmp/mem-dumps", "#{rname}-#{mode}-#{tree}-#{app}") if opts[:detail]
        FileUtils.mkdir_p(dumps) if dumps
        begin
          Census.sh(env, "bundle", "exec", "ruby", *Census::FLAGS.fetch(mode), File.join(HERE, "mem.rb"), app, out, *dumps,
            chdir: Census.app_dir(opts[:corpus], app), log: out.sub(/\.jsonl\z/, ".log"))
          if dumps
            Census.sh({ "PATH" => "#{bin}:#{ENV.fetch("PATH")}" }, "ruby", File.join(HERE, "dump.rb"), dumps,
              Census.app_dir(opts[:corpus], app), out, out.sub(/\.jsonl\z/, ".dump.json"), log: out.sub(/\.jsonl\z/, ".dump.log"))
            FileUtils.rm_rf(dumps)
          end
        rescue RuntimeError => e
          warn "#{app} #{rname} #{mode} #{tree} #{kind}: #{e.message}"
          failed << out
        end
      end
    end
  end
end.each(&:join)
failures = Array.new(failed.size) { failed.pop }
abort "failed: #{failures.join(", ")}" if failures.any?
puts "done"
