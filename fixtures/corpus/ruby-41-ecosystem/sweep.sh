#!/bin/bash
# Ruby 4.1 ecosystem sweep (docs/upstream/ruby-4.1-ecosystem.md).
# Builds every native-extension gem locked by the census apps, plus each
# such gem's latest release, on Ruby 4.0.7 and Ruby master, and diffs the
# public C headers.
#
#   sweep.sh WORK RUBY407 RUBYMASTER RUBY_SRC
#
# WORK is a scratch directory. RUBY407 and RUBYMASTER are ruby binaries.
# RUBY_SRC is a ruby/ruby checkout that has v4.0.7 and the master commit.
# Needs curl, jq, nm, a C/C++ toolchain, cargo and clang (for rb-sys).
set -euo pipefail
work=$1 r407=$2 rmas=$3 src=$4
here=$(cd "$(dirname "$0")/../../.." && pwd)
mkdir -p "$work"/{locks,gems,src,ext,build}
cd "$work"

# 1. Lockfiles at the pins in script/corpus (blog: its census 4 copy).
awk '/^  [a-z0-9-]+\)$/{n=$1;sub(/\)/,"",n)} /rev=/{r=$1;sub(/rev=/,"",r)}
     /repo=/{u=$1;sub(/repo=/,"",u); print n, r, u}' "$here/script/corpus" |
  grep -vE '^(real-blog|campfire-r81|campfire-r82|fizzy-r82|writebook-r82|wikino) ' > locks/apps.txt
while read -r n r u; do
  curl -sfL "https://raw.githubusercontent.com/${u#https://github.com/}/$r/Gemfile.lock" -o "locks/$n.lock"
done < locks/apps.txt
cp "$here/.corpus/census4-blog/Gemfile.lock" locks/blog.lock
touch locks/Gemfile
(cd locks && "$r407" -rbundler -e '
  all = Hash.new { |h, k| h[k] = [] }
  Dir["*.lock"].sort.each do |f|
    Bundler::LockfileParser.new(File.read(f)).specs.each do |s|
      next unless s.source.is_a?(Bundler::Source::Rubygems)
      all[[s.name, s.version.to_s]] |= [File.basename(f, ".lock")]
    end
  end
  File.write("apps_by_gem.tsv", all.map { |(n, v), a| [n, v, a.join(",")].join("\t") }.join("\n") + "\n")')

# 2. Source gems, extension gems, their latest releases.
cut -f1,2 locks/apps_by_gem.tsv | tr '\t' - | sort -u > ext/locked.txt
xargs -P24 -I{} sh -c 'test -s gems/{}.gem || curl -sfL -o gems/{}.gem https://rubygems.org/downloads/{}.gem || echo "missing {}"' < ext/locked.txt
while read -r b; do
  [ -s "gems/$b.gem" ] && tar -xOf "gems/$b.gem" metadata.gz | gunzip | grep -q '^extensions: *$' && echo "$b"
done < ext/locked.txt > ext/with-ext.txt || true
sed -E 's/-[0-9][^-]*$//' ext/with-ext.txt | sort -u | while read -r n; do
  v=$(curl -sf "https://rubygems.org/api/v1/versions/$n/latest.json" | jq -r .version)
  [ -s "gems/$n-$v.gem" ] || curl -sfL -o "gems/$n-$v.gem" "https://rubygems.org/downloads/$n-$v.gem"
  echo "$n-$v" >> ext/with-ext.txt
done
# libv8-node, mini_racer, grpc and sass-embedded are skipped: vendored
# toolchains, no C API use beyond comments (checked by grep).
sort -u ext/with-ext.txt | grep -vE '^(libv8-node|mini_racer|grpc|sass-embedded)-' > ext/buildlist.txt

# 3. Build on both Rubies. rb-sys needs `ruby` on PATH.
build() {
  label=$1 ruby=$2 b=$3 out=$work/build/$1
  mkdir -p "$out/logs"; [ -f "$out/logs/$b.rc" ] && return 0
  PATH=$(dirname "$ruby"):$PATH MAKEFLAGS=-j2 timeout 1800 "$ruby" "$(dirname "$ruby")/gem" install \
    --local --ignore-dependencies --no-document --install-dir "$out/home" "gems/$b.gem" > "$out/logs/$b.log" 2>&1
  echo $? > "$out/logs/$b.rc"
}
export -f build; export work
xargs -P4 -I{} bash -c 'build master "$0" {}' "$rmas" < ext/buildlist.txt
xargs -P4 -I{} bash -c 'build r407 "$0" {}' "$r407" < ext/buildlist.txt

# 4. Built extensions must not import a symbol master no longer exports.
nm -D --defined-only "$rmas" | awk '{print $NF}' | sort -u > ext/master-syms.txt
find build/master/home -name '*.so' | while read -r so; do
  comm -23 <(nm -D --undefined-only "$so" | awk '{print $NF}' | sed 's/@.*//' |
             grep -E '^(rb_|ruby_|st_|onig|rbimpl)' | sort -u) ext/master-syms.txt | sed "s|^|$so\t|"
done > ext/undefined.tsv

# 5. Identifiers in include/ on v4.0.7 but not on master.
for r in v4.0.7 "$("$rmas" -e 'print RUBY_REVISION[0,10]')"; do
  git -C "$src" archive "$r" include | tar -x -C "$work" --transform "s|^include|inc-$r|"
done
ids() { grep -rhoE '\b(rb|ruby|RB|RUBY|R[A-Z]+|Data|DATA|OBJ|rb_[a-z])[A-Za-z0-9_]*\b' "$1" | sort -u; }
comm -23 <(ids inc-v4.0.7) <(ids "inc-$("$rmas" -e 'print RUBY_REVISION[0,10]')") > ext/removed.txt

printf 'gem\tversion\tmaster\tr407\n' > ext/results.tsv
while read -r b; do
  printf '%s\t%s\t%s\t%s\n' "${b%-*}" "${b##*-}" "$(cat "build/master/logs/$b.rc")" "$(cat "build/r407/logs/$b.rc" 2>/dev/null || echo -)"
done < ext/buildlist.txt >> ext/results.tsv
awk -F'\t' 'NR > 1 && $3 != 0' ext/results.tsv
