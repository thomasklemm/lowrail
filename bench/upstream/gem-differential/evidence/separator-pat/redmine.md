Tracker: Bug. Subject:

bundle install fails with "uninitialized constant Pathname::SEPARATOR_PAT" for lockfiles from Bundler before 4.0.12

Description:

On master, `bundle install` fails when the lockfile was written by Bundler 2.x or 4.0.0 to 4.0.11 and has a path or git source, such as a gem repository whose Gemfile says `gemspec`:

```
Bundler 4.1.1 is running, but your lockfile was generated with 2.6.9. Installing Bundler 2.6.9 and restarting using that version.
NameError: uninitialized constant Pathname::SEPARATOR_PAT
  .../gems/bundler-2.6.9/lib/bundler/source/path.rb:218:in 'block in Bundler::Source::Path#generate_bin'
```

Bundler switches to the version in `BUNDLED WITH`, and Bundler before 4.0.12 reads `Pathname::SEPARATOR_PAT` for every path and git gem. 4e243c709e made the constant private and a5996718f3 removed it; Bundler itself stopped using it in https://github.com/ruby/rubygems/pull/9529. Lockfiles with only rubygems.org gems still install, and `bundle update --bundler` fixes an affected repository.

To reproduce (Ruby 4.0 installs, master raises):

```
mkdir foo && cd foo
mkdir lib && echo 'module Foo; end' > lib/foo.rb
cat > foo.gemspec <<'G'
Gem::Specification.new do |s|
  s.name = "foo"; s.version = "0.1.0"; s.summary = "foo"; s.authors = ["x"]; s.files = ["lib/foo.rb"]
end
G
printf 'source "https://rubygems.org"\ngemspec\n' > Gemfile
bundle lock
sed -i '/BUNDLED WITH/{n;s/.*/   2.6.9/}' Gemfile.lock
bundle install
```

If these lockfiles should keep working, defining the constant again as deprecated in `pathname_builtin.rb` is enough:

```ruby
SEPARATOR_PAT = File::ALT_SEPARATOR ? /[#{Regexp.quote(File::ALT_SEPARATOR + File::SEPARATOR)}]/ : /#{Regexp.quote(File::SEPARATOR)}/
deprecate_constant :SEPARATOR_PAT
```

I can open a pull request with this and a test if that is the preferred fix.
