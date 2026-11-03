# Per-call cost of Active Record `order` arguments (rails/rails#59577).
#
#   cd RAILS && RAILS=$PWD bundle exec ruby [--yjit|--zjit] bench.rb stats CASE
#     objects per call and best-of-7 ns per call
#   cd RAILS && RAILS=$PWD bundle exec ruby [--yjit|--zjit] bench.rb ir CASE N
#     warm up, then N calls with GC disabled; run under Callgrind with N and 0
#     and divide the Ir difference by N (see ir.sh)
#
# RAILS is the Rails checkout under test. Run it once per checkout, base twice
# for an A/A pair.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.timestamps }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; end
AUTHOR = Author.create!(name: "a")
3.times { AUTHOR.posts.create!(title: "t") }
REL = Post.all

CASES = {
  "order_id" => -> { Post.order(:id).to_a },
  "order_hash" => -> { Post.order(created_at: :desc).to_a },
  "assoc_order" => -> { AUTHOR.posts.reset; AUTHOR.posts.order(:id).to_a },
  "pre_id" => -> { REL.send(:preprocess_order_args, [:id]) },
  "pre_hash" => -> { REL.send(:preprocess_order_args, [{ created_at: :desc }]) },
}

mode, name, n = ARGV[0], ARGV[1], Integer(ARGV[2] || 0)
fn = CASES.fetch(name)
500.times { fn.() }

case mode
when "ir"
  GC.start
  GC.disable
  i = 0
  while i < n
    fn.()
    i += 1
  end
when "stats"
  GC.disable
  before = GC.stat(:total_allocated_objects)
  1000.times { fn.() }
  objects = (GC.stat(:total_allocated_objects) - before) / 1000.0
  GC.enable
  k = name.start_with?("pre") ? 50_000 : 5_000
  ns = 7.times.map do
    GC.start
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    k.times { fn.() }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t) / k.to_f
  end.min
  puts format("%s objects=%.1f ns=%.1f", name, objects, ns)
else
  abort "usage: bench.rb stats|ir CASE [N]"
end
