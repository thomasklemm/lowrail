# Usage: ruby force_ruby.rb APPDIR gem:version...
dir, *pairs = ARGV
path = File.join(dir, "Gemfile")
src = File.read(path)
src = src.gsub(/^([ \t]*ruby file: "\.ruby-version".*)$/) { "# #{$1} # ruby41-watch: one bundle for 4.0.7 and master" }
pairs.each do |pair|
  name, version = pair.split(":")
  re = /^([ \t]*gem[ \t]+["']#{Regexp.escape(name)}["'][^#\n]*?)([ \t]*(#.*)?)$/
  if src.match?(re)
    src = src.sub(re) { "#{$1}, force_ruby_platform: true#{$2}" }
  else
    src << %(\ngem "#{name}", "= #{version}", force_ruby_platform: true # ruby41-watch: no 4.1 binary\n)
  end
end
File.write(path, src)
