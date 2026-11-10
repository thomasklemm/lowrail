# ruby --yjit ir.rb N : N raising/throwing/breaking/normal dynamic sends after warmup; prints JIT-flat check
N = Integer(ARGV[0])
TARGET = Object.new
def TARGET.call = yield
def ok    = TARGET.call { 1 }
def rai   = (TARGET.call { raise "x" } rescue nil)
def thr   = catch(:t) { TARGET.call { throw :t } }
def brk   = TARGET.call { break 2 }
def one = (ok; rai; thr; brk)
2000.times { one }
K = %i[compiled_iseq_count compiled_block_count invalidation_count]
GC.start; GC.disable
a = RubyVM::YJIT.runtime_stats.slice(*K)
i = 0
while i < N
  one
  i += 1
end
b = RubyVM::YJIT.runtime_stats.slice(*K)
warn "flat=#{a == b} #{b} code=#{RubyVM::YJIT.runtime_stats.values_at(:inline_code_size, :outlined_code_size)}"
