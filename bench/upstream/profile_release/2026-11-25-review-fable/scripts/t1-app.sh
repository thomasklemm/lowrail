#!/usr/bin/env bash
# t1-app.sh RUBY SRC DIR : a copy of the fresh app with path gems inside the root (engines/, gems/, vendor/gems/),
# outside it, through a symlink (with a require_relative file), a git: gem and a file in no gem. Each allocates a
# distinct number of Strings per ArticlesController#index, so every one can be found in the report.
set -euo pipefail
ruby=$1 src=$2 dir=$3
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh" "$ruby"
base=$(dirname "$dir")
rm -rf "$dir" "$base/t1-outer" "$base/t1-linked" "$base/t1-linked-real" "$base/t1-gitgem" "$base/t1-loose"
git clone -q "$src" "$dir"; cd "$dir"; git checkout -q "$(git rev-list --max-parents=0 HEAD)" 2>/dev/null || true
mkgem() { # dir name count [extra]
  mkdir -p "$1/lib"
  mod=$(ruby -e 'print ARGV[0].split("_").map(&:capitalize).join' "$2")
  printf 'Gem::Specification.new do |s|\n  s.name = "%s"\n  s.version = "0.1.0"\n  s.summary = "x"\n  s.authors = ["x"]\n  s.files = Dir["lib/**/*.rb"]\nend\n' "$2" > "$1/$2.gemspec"
  printf 'module %s\n  def self.many = Array.new(%s) { String.new }\nend\n' "$mod" "$3" > "$1/lib/$2.rb"
}
mkgem engines/inner inner 11
mkgem gems/gitlab_like gitlab_like 13
mkgem vendor/gems/vendored vendored 17
mkgem "$base/t1-outer" outer 19
mkgem "$base/t1-linked-real" linked 23
mkdir -p "$base/t1-linked-real/lib/linked"
printf 'module Linked\n  module Deep\n    def self.many = Array.new(29) { String.new }\n  end\nend\n' > "$base/t1-linked-real/lib/linked/deep.rb"
printf 'require_relative "linked/deep"\n' >> "$base/t1-linked-real/lib/linked.rb"
ln -s t1-linked-real "$base/t1-linked"
mkgem "$base/t1-gitgem" gitgem 31
(cd "$base/t1-gitgem" && git init -q && git add -A && git -c user.name=x -c user.email=x@x commit -qm x)
mkdir -p "$base/t1-loose"
printf 'module Loose\n  def self.many = Array.new(37) { String.new }\nend\n' > "$base/t1-loose/loose.rb"
cat >> Gemfile <<G
gem "inner", path: "engines/inner"
gem "gitlab_like", path: "gems/gitlab_like"
gem "vendored", path: "vendor/gems/vendored"
gem "outer", path: "../t1-outer"
gem "linked", path: "../t1-linked"
gem "gitgem", git: "file://$base/t1-gitgem"
G
printf 'require "%s"\n' "$base/t1-loose/loose.rb" > config/initializers/loose.rb
ruby -pi -e 'sub(/^    @articles = Article.all\n/, %(    @articles = Article.all\n    [Inner, GitlabLike, Vendored, Outer, Linked, Linked::Deep, Gitgem, Loose].each(&:many)\n))' app/controllers/articles_controller.rb
grep -n "many" app/controllers/articles_controller.rb
bundle install >/dev/null
git add -A && git -c user.name=x -c user.email=x@x commit -qm t1
PARALLEL_WORKERS=1 bin/rails test 2>&1 | tail -2
