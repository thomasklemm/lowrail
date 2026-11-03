require "bundler"
a = Bundler::LockfileParser.new(File.read(ARGV[0])).specs.map { [_1.name, _1.version.to_s] }.uniq.to_h
b = Bundler::LockfileParser.new(File.read(ARGV[1])).specs.map { [_1.name, _1.version.to_s] }.uniq.to_h
diff = (a.keys | b.keys).filter_map { |n| "#{n} #{a[n].inspect}->#{b[n].inspect}" if a[n] != b[n] }
puts "#{ARGV[1]}: #{diff.empty? ? "same versions" : diff.join(", ")}"
