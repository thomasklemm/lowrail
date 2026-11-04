# Like nosingleton.rb, but the Hash reads happen in methods that are too big
# to inline, so compiled callers call them JIT-to-JIT.
class Store
  def initialize = @h = { a: 1, b: 2 }
  def get(k)
    v = @h[k]
    v = @h[:b] if v.nil?
    x = @h.size
    x += 1 if @h.key?(k)
    [v, x].first + helper
  end
end
STORE = Store.new
class Store; def helper = 0; end
def caller_a(k) = STORE.get(k)
def request(define)
  env = {}
  def env.http_accept_language = 1 if define
  1000.times { caller_a(:a) }
  GC.start if ENV["GC_EACH"]
end
define = ARGV[0] == "define"
300.times { request(false) }   # compile with no Hash singleton class yet
3.times do                     # spend three versions on method redefinition, as boot and reloading do
  Store.class_eval { def helper = 0 }
  300.times { request(false) }
end
300.times { request(define) }  # then one singleton class per request
RubyVM::ZJIT.reset_stats!
100.times { request(define) }
s = RubyVM::ZJIT.stats
puts(define ? "define (100 requests):" : "no define (100 requests):")
p s.select { |k, v| v.is_a?(Integer) && v > 0 && k.match?(/^exit_|singleton|compiled_iseq_count|version_limit|side_exit_count/) }
