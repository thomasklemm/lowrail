U = "a-zA-Z0-9\\-\\._~"; S = "!\\$&'\\(\\)\\*\\+,;=:@"
PAT = { "atomic" => /\A(?>[#{U}#{S}]*)\z/, "plusposs" => /\A[#{U}#{S}]++\z/, "lookahead" => /\A(?![\s\S]*[^#{U}#{S}])/ }
kind, n = ARGV[0], Integer(ARGV[1]); s = "a" * n
b = File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i; r = s.match?(PAT.fetch(kind))
puts "#{kind} n=#{n} match=#{r} delta=#{File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i - b}kB"
