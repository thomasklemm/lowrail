# Usage (from rails/<component>): ruby -r~/jitdiff/outcomes run_component.rb [files] --seed N
root = File.expand_path("..", Dir.pwd)
component = File.basename(Dir.pwd)
Dir[File.join(root, "*/*.gemspec")].each do |gemspec|
  name = File.basename(gemspec, ".gemspec")
  spec = Gem::Specification.load(gemspec)
  spec.full_gem_path = File.dirname(gemspec)
  Gem.loaded_specs[name] = spec
  $LOAD_PATH.unshift(File.join(File.dirname(gemspec), "lib"))
end
$LOAD_PATH.unshift(File.join(root, "railties/lib"), File.join(Dir.pwd, "test"))
ENV["ARCONN"] ||= "sqlite3_mem"
files = ARGV.take_while { !_1.start_with?("-") }
ARGV.shift(files.size)
if files.empty? && (g = ENV["JITDIFF_GROUP"])
  files = Dir["test/#{g}/**/*_test.rb"].sort
end
if files.empty?
  files = case component
  when "activerecord"
    Dir["test/cases/**/*_test.rb"].sort.reject { _1.include?("/adapters/") || _1.include?("/encryption/performance/") } +
      Dir["test/cases/adapters/#{ENV.fetch('ARCONN').split('_').first}/**/*_test.rb"].sort
  when "activemodel", "activejob"
    Dir["test/cases/**/*_test.rb"].sort.reject { component == "activejob" && (_1.include?("delayed_job") || _1.include?("async")) }
  when "actionview"
    Dir["test/template/**/*_test.rb"].sort
  else
    Dir["test/**/*_test.rb"].sort.reject { _1.start_with?("test/fixtures/", "test/isolation/assets/") }
  end
end
files.each { require File.expand_path(_1) }
