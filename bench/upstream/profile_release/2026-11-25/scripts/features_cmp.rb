# ruby features_cmp.rb OUTDIR [BASE] [SETS] [EXTRA_REJECT_REGEX]: per process, compares $LOADED_FEATURES order of
# each set's processes (profiled sets: only run*-PID files) against the BASE processes (default plain),
# outside Lowrail, Bundler and RubyGems.
dir = ARGV.fetch(0)
base_name = ARGV[1] || "plain"
names = (ARGV[2] || "off,profiled").split(",")
extra = ARGV[3] && Regexp.new(ARGV[3])
norm = ->(f) { File.readlines(f, chomp: true).reject { _1.include?("/lowrail") || _1.match?(%r{/bundler[-/.]|/rubygems[/.]|rubygems/}) || (extra && _1.match?(extra)) } }
load = ->(s) { Dir["#{dir}/#{s}.features/*.txt"].reject { !s.match?(/\A(plain|off)/) && !File.basename(_1).start_with?("run") }.map { [File.basename(_1), norm.(_1)] } }
base = load.(base_name).map(&:last)
puts "base #{base_name}: #{base.size} processes"
names.each do |s|
  load.(s).each do |name, list|
    match = base.include?(list)
    puts "#{s} #{name} #{list.size}: #{match ? "identical to a #{base_name} process" : "DIFFERS"}"
    next if match
    near = base.min_by { (_1 - list).size + (list - _1).size }
    puts "  extra: #{(list - near).first(5)}  missing: #{(near - list).first(5)}  same set: #{near.sort == list.sort}"
  end
end
