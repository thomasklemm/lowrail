# frozen_string_literal: true

# Five fresh YJIT processes; paired shadow-off/strict order alternates. Stats
# are enabled in both, as in verify. This measures test-mode cost, not speedup.
require_relative "ar_equivalence"

if ARGV.first == "--worker"
  ENV["LOWRAIL"] = "1"
  AREquivalence.schema
  Lowrail::AREquivalenceRuntime.build
  owner = EqWriter.find(1)
  association = owner.association(:preferred_posts)
  result = EqPost.with_connection { _1.select_all(EqPost.all.arel) }
  cases = {
    "reader" => -> { association.reset; association.reset_scope; owner.preferred_posts.to_a },
    "preload" => -> { EqWriter.preload(posts: :notes).to_a },
    "instantiate_7_rows" => -> { EqPost._load_from_sql(result) }
  }
  out = {}
  ARGV.fetch(1).split(",").each do |mode|
    ENV["LOWRAIL_SHADOW"] = mode
    out[mode] = cases.to_h do |name, work|
      200.times { work.call }
      GC.start
      allocations = GC.stat(:total_allocated_objects)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      n = Integer(ENV.fetch("ITERATIONS", "1000"))
      n.times { work.call }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      [name, { "us" => elapsed * 1_000_000 / n,
        "objects" => (GC.stat(:total_allocated_objects) - allocations).fdiv(n) }]
    end
  end
  puts JSON.generate(out)
else
  runs = 5.times.map do |i|
    modes = i.even? ? "0,strict" : "strict,0"
    out, err, status = Open3.capture3(RbConfig.ruby, "--yjit", "-I#{File.expand_path('../gem/lib', __dir__)}", __FILE__, "--worker", modes)
    raise err unless status.success?
    JSON.parse(out.lines.last)
  end
  puts JSON.pretty_generate({ "ruby" => RUBY_DESCRIPTION, "stats" => true, "runs" => runs })
end
