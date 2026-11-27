mkdir foo && cd foo && mkdir lib && echo 'module Foo; end' > lib/foo.rb
cat > foo.gemspec <<'G'
Gem::Specification.new do |s|
  s.name = "foo"; s.version = "0.1.0"; s.summary = "foo"; s.authors = ["x"]; s.files = ["lib/foo.rb"]
end
G
printf 'source "https://rubygems.org"\ngemspec\n' > Gemfile
bundle lock
sed -i '/BUNDLED WITH/{n;s/.*/   2.7.2/}' Gemfile.lock
bundle install
