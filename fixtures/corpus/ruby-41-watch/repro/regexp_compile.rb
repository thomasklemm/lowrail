require "objspace"
pats = { "^localhost$/i" => ["^localhost$", Regexp::IGNORECASE], "^localhost$" => ["^localhost$", 0], "\\A[a-z]+\\z" => ['\A[a-z]+\z', 0],
  "(\\w+)@(\\w+)\\.com" => ['(\w+)@(\w+)\.com', 0], "abc" => ["abc", 0], "a|b|c|d" => ["a|b|c|d", 0], "[[:alpha:]]+" => ["[[:alpha:]]+", 0] }
pats.each do |name, (src, opt)|
  r = Regexp.new(src, opt)
  n = 100_000
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC); i = 0; while i < n; Regexp.new(src, opt); i += 1; end
  dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
  printf("%-22s memsize %5d  compile %6.0f ns  match %s\n", name, ObjectSpace.memsize_of(r), dt * 1e9 / n, ("localhost" =~ r).inspect)
end
