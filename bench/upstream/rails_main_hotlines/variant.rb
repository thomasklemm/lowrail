# ruby variant.rb DIR TREE SHA: writes DIR/Gemfile.TREE (+ .lock) from the app's own Gemfile and lock, with every
# Rails gem line pinned to rails/rails at SHA (as script/census's variant does) and lowrail-profile added for tests.
# SHA "own" keeps the app's own Rails (apps whose lock already is Rails main and that set load_defaults 8.2).
dir, tree, sha = ARGV
rails = %w[rails railties actioncable actionmailbox actionmailer actionpack actiontext actionview activejob
  activemodel activerecord activestorage activesupport]
lines = File.readlines(File.join(dir, "Gemfile"))
unless sha == "own"
  pins = lines.each_index.select { |i| lines[i] =~ /\A\s*gem ["'](#{rails.join("|")})["'](?:,|\s*(?:#.*)?$)/ }
  abort "#{dir}: no Rails gem line" if pins.empty?
  pins.each { |i| lines[i] = %(gem "#{lines[i][/["'](\w+)["']/, 1]}", github: "rails/rails", ref: "#{sha}"\n) }
end
lines[-1] += "\n" unless lines[-1].end_with?("\n")
lines << %(gem "lowrail-profile", "0.1.0.rc1", group: [:development, :test], require: false\n)
File.write(File.join(dir, "Gemfile.#{tree}"), lines.join)
File.write(File.join(dir, "Gemfile.#{tree}.lock"), File.read(File.join(dir, "Gemfile.lock")))
