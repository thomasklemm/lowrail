require "bundler"
v = Gem::Version.new("4.1.0.dev")
ARGV.each do |dir|
  lock = Bundler::LockfileParser.new(File.read(File.join(dir, "Gemfile.lock")))
  bad = lock.specs.select { |s| s.platform.to_s =~ /x86_64-linux(-gnu)?\z/ }.filter_map do |s|
    spec = Gem::Specification.find_all_by_name(s.name, s.version).find { _1.platform.to_s == s.platform.to_s }
    next "#{s.full_name}(not installed)" unless spec
    "#{s.name} #{s.version} (#{spec.required_ruby_version})" unless spec.required_ruby_version.satisfied_by?(v)
  end
  puts "#{File.basename(dir)}: #{bad.join(", ")}"
end
