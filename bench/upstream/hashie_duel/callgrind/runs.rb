# Under Valgrind (DUEL_CALLGRIND set), in a hashie checkout: one benchmark's
# per-run instruction counts, through Duel's own worker.
require "duel"
require "duel/worker"
root = Dir.pwd
config = Duel.load_config(File.join(root, ".duel.rb"))
config.load_into(root)
TOPLEVEL_BINDING.receiver.extend(Duel::DSL)
config.benchmark_files.each { |file| load file }
GC.start
worker = Duel::Worker.new(config.metrics, config.measures, hooks: config.hooks)
name = ENV.fetch("BENCH")
n = Integer(ENV.fetch("N", "8"))
p worker.handle({"op" => "setup", "name" => name})
values = Array.new(Integer(ENV.fetch("SAMPLES", "60"))) do
  worker.handle({"op" => "sample", "name" => name, "n" => n, "runs" => 1}).fetch("timed").fetch("instructions")
end
puts values.join(" ")
tally = values.tally.sort_by { |v, _| v }
puts "min #{values.min} median #{values.sort[values.size / 2]} max #{values.max} distinct #{tally.size}"
puts tally.first(8).map { |v, c| "#{v}x#{c}" }.join(" ")
