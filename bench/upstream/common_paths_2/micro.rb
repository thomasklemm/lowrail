# ruby micro.rb CASE N MODE   (MODE: ir | ns | obj); run from a Rails worktree (RAILS=$PWD)
require "bundler/setup"
require_relative "setup"

CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"

post = Post.create!(title: "t", author: AUTHOR)
post_id = post.id
TYPE = Post.type_for_attribute("created_at")
NOW = Time.current

CASES = {
  # CP-3: resolve_attribute_name
  "type_for_attribute" => -> { Post.type_for_attribute("title") },
  "where_two" => -> { Post.where(title: "t", published: false).to_a },
  "belongs_to" => -> { post.association(:author).reset; post.author },
  # CP-4: apply_seconds_precision
  "cast_time" => -> { TYPE.cast(Time.now) },
  "cast_twz" => -> { TYPE.cast(NOW) },
  "create" => -> { Post.create!(title: "x", author_id: AUTHOR.id) },
  "touch" => -> { post.touch },
  "where_time" => -> { Post.where(created_at: ..NOW).first },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start
GC.disable
case MODE
when "ir"
  [0].cycle(1) { N.times { f.() } }
when "obj"
  b = GC.stat(:total_allocated_objects)
  N.times { f.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
