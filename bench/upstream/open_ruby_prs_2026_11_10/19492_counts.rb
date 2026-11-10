# ruby --yjit --yjit-stats=quiet --yjit-call-threshold=1 counts.rb N
N = Integer(ARGV[0])
TARGET = Object.new
def TARGET.call = yield   # singleton receiver: YJIT dispatches dynamically
def ok    = TARGET.call { 1 }
def rai   = (TARGET.call { raise "x" } rescue nil)
def thr   = catch(:t) { TARGET.call { throw :t } }
def brk   = TARGET.call { break 2 }
res = {}
%i[ok rai thr brk].each do |m|
  3.times { send(m) }
  RubyVM::YJIT.reset_stats!
  i = 0
  while i < N
    case m when :ok then ok when :rai then rai when :thr then thr else brk end
    i += 1
  end
  s = RubyVM::YJIT.runtime_stats
  res[m] = [s[:num_send_dynamic], s[:send_singleton_class]]
end
p res
