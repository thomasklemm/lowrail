# sections.rb FILE...: per "=== name ===" section, which files agree with the last one.
files = ARGV
parse = ->(f) { File.read(f).split(/^(?==== )/).drop(1).to_h { |s| [s.lines.first.strip, s] } }
target = parse.(files.last)
others = files[0..-2].to_h { |f| [File.basename(f)[/matrix-(\w+)-/, 1], parse.(f)] }
target.each { |k, v| puts "#{k}: #{others.select { |_, h| h[k] == v }.keys.join(' ')}" }
