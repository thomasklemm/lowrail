U = "a-zA-Z0-9\\-\\._~"; S = "!\\$&'\\(\\)\\*\\+,;="
PAT = { "neg" => /[^#{U}#{S}:@]/, "anch" => /\A[#{U}#{S}:@]*\z/, "poss" => /\A[#{U}#{S}:@]*+\z/ }
kind, n = ARGV[0], Integer(ARGV[1])
s = "a" * n
base = File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i
r = s.match?(PAT.fetch(kind))
peak = File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i
puts "#{kind} n=#{n} match=#{r} hwm_before=#{base}kB hwm_after=#{peak}kB delta=#{peak - base}kB"
