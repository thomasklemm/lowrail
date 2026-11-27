Tracker: Bug. Subject:

bundle install can fail with "uninitialized constant Pathname::SEPARATOR_PAT" for lockfiles from older Bundler

Description:

On master, `bundle install` can fail when the lockfile was written by an older Bundler, such as 2.6.9, and has a path or git gem with files, for example the gem of a repository whose Gemfile says `gemspec`:

```
Bundler 4.1.1 is running, but your lockfile was generated with 2.6.9. Installing Bundler 2.6.9 and restarting using that version.
NameError: uninitialized constant Pathname::SEPARATOR_PAT
  .../gems/bundler-2.6.9/lib/bundler/source/path.rb:218:in 'block in Bundler::Source::Path#generate_bin'
```

By default, Bundler switches to the version in `BUNDLED WITH`, and Bundler 2.6.9 reads `Pathname::SEPARATOR_PAT` while checking the files of a path or git gem ([path.rb:218](https://github.com/ruby/rubygems/blob/8a2a14d63da701e980f856d8772d273fd448b8a1/bundler/lib/bundler/source/path.rb#L218)). 4e243c709e made the constant private and a5996718f3 removed it; Bundler 4.0.12 removed this use (https://github.com/ruby/rubygems/pull/9529). Rubygems-only sources do not use this constant. Outside frozen or deployment mode, `bundle _4.1.1_ update --bundler` updates the lockfile. With Bundler 4.1, `BUNDLE_VERSION=system bundle install` avoids the version switch.

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
