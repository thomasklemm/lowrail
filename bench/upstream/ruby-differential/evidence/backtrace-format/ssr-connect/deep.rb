require "net/http"
n = Integer(ARGV[0] || 200)
uri = URI("http://localhost:13714/render")
g = -> { begin; Net::HTTP.post(uri, "{}", "Content-Type" => "application/json"); rescue => e; e; end }
def d(k, g) = k.zero? ? g.() : d(k - 1, g)
f = -> { d(Integer(ENV.fetch("DEPTH","150")), g) }
20.times { f.() }
GC.disable
t = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
n.times { f.() }
p [RUBY_VERSION, f.().class, f.().message[0,90], ((Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)-t)/n*1e6).round(1)]
