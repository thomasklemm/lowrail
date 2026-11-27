#!/usr/bin/env bash
# Sets up one orb for docs/upstream/zjit-gap-census-3.md: Ruby master at the pin (YJIT + ZJIT, release),
# ruby-bench with railsbench and lobsters on Rails main, and the census copies of Campfire and Writebook.
#   bench/upstream/zjit-gap-3/setup.sh [ruby|headline|bench|census]...   (default: all four)
# headline builds k0kubun/ruby zjit-headline6 at its pin; bench and census also bundle for it when it is built.
set -euo pipefail
RUBY_SHA=0d399335b733776187e43a783e5f950c18ad881c
RAILS_SHA=2e299253f942ab94041cc6f210ac9d33884c210d
BENCH_SHA=43d41e22d7fa42e15d07b44e8c78c44960a3feac
HEADLINE_SHA=5c4239a16d5700c6742f5585972461fc77a330c5
root=$(cd "$(dirname "$0")/../../.." && pwd)
prefix=$HOME/rubies/master-${RUBY_SHA:0:10}
hprefix=$HOME/rubies/h6-${HEADLINE_SHA:0:10}
base=$("$HOME/.local/bin/mise" where ruby@4.0.9)/bin
mkdir -p ~/w ~/rubies
steps=("$@"); [ ${#steps[@]} -gt 0 ] || steps=(ruby headline bench census)

fetch() { # DIR URL SHA
  [ -d "$1/.git" ] || { git init --quiet "$1"; git -C "$1" remote add origin "$2"; }
  git -C "$1" cat-file -e "$3^{commit}" 2>/dev/null || git -C "$1" fetch --quiet --depth 1 origin "$3"
  git -C "$1" checkout --quiet --detach "$3"
}

for step in "${steps[@]}"; do
  case $step in
  ruby)
    [ -x "$prefix/bin/ruby" ] && continue
    fetch ~/w/ruby-src https://github.com/ruby/ruby $RUBY_SHA
    cd ~/w/ruby-src && PATH=$base:$HOME/.cargo/bin:$PATH ./autogen.sh
    mkdir -p build && cd build
    PATH=$base:$HOME/.cargo/bin:$PATH ../configure --prefix="$prefix" --enable-zjit --enable-yjit --disable-install-doc \
      --with-baseruby="$base/ruby" optflags=-O3 > /tmp/configure.log 2>&1
    PATH=$base:$HOME/.cargo/bin:$PATH make -j"$(nproc)" > /tmp/make.log 2>&1
    make install > /tmp/install.log 2>&1
    "$prefix/bin/ruby" --zjit -v
    ;;
  headline)
    [ -x "$hprefix/bin/ruby" ] && continue
    [ -d ~/w/ruby-h6/.git ] || { git init --quiet ~/w/ruby-h6; git -C ~/w/ruby-h6 remote add origin https://github.com/k0kubun/ruby; }
    git -C ~/w/ruby-h6 cat-file -e "$HEADLINE_SHA^{commit}" 2>/dev/null || git -C ~/w/ruby-h6 fetch --quiet --depth 1 origin $HEADLINE_SHA
    git -C ~/w/ruby-h6 checkout --quiet --detach $HEADLINE_SHA
    cd ~/w/ruby-h6 && PATH=$base:$HOME/.cargo/bin:$PATH ./autogen.sh
    mkdir -p build && cd build
    PATH=$base:$HOME/.cargo/bin:$PATH ../configure --prefix="$hprefix" --enable-zjit --enable-yjit --disable-install-doc \
      --with-baseruby="$base/ruby" optflags=-O3 > /tmp/configure-h6.log 2>&1
    PATH=$base:$HOME/.cargo/bin:$PATH make -j"$(nproc)" > /tmp/make-h6.log 2>&1
    make install > /tmp/install-h6.log 2>&1
    "$hprefix/bin/ruby" --zjit -v
    ;;
  bench)
    fetch ~/w/rails-main https://github.com/rails/rails $RAILS_SHA
    fetch ~/w/ruby-bench https://github.com/ruby/ruby-bench $BENCH_SHA
    cd ~/w/ruby-bench
    cp "$root/bench/upstream/zjit-gap-3/wall_harness.rb" harness/gapwall.rb
    cp "$root/bench/upstream/zjit_yjit_gap_harness.rb" harness/gap.rb
    # What Rails 8.2 defaults need in these apps (combined-effect round 3's patch, without its Gemfiles).
    git apply --include='benchmarks/*/config/*' "$root/bench/upstream/combined_r3/ruby-bench.patch" 2>/dev/null ||
      git apply --reverse --check --include='benchmarks/*/config/*' "$root/bench/upstream/combined_r3/ruby-bench.patch"
    if [ ! -d benchmarks/shipit/vendor/shipit-engine ]; then
      mkdir -p benchmarks/shipit/vendor
      (cd benchmarks/shipit/vendor && PATH=$base:$PATH gem fetch shipit-engine -v 0.45.0 > /dev/null &&
        PATH=$base:$PATH gem unpack shipit-engine-0.45.0.gem > /dev/null && mv shipit-engine-0.45.0 shipit-engine &&
        PATH=$base:$PATH gem spec shipit-engine-0.45.0.gem --ruby > shipit-engine/shipit-engine.gemspec && rm shipit-engine-0.45.0.gem)
      (cd benchmarks/shipit/vendor/shipit-engine && patch -p1 --quiet < "$root/bench/upstream/index_with_ruby_bench/shipit-engine-review_stack.patch")
    fi
    for b in railsbench lobsters shipit; do
      d=benchmarks/$b
      # Rails main by path and prism; everything else stays at ruby-bench's lock where it still resolves.
      "$base/ruby" -e 'src = File.read(ARGV[0])
        src.sub!(/gem rails_gem, .~> 8\.\d.\n/) { "gem rails_gem, path: #{ARGV[1].dump}\n" } or
          src.sub!(/gem "rails", "~> 8\.\d"\n/) { "gem \"rails\", path: #{ARGV[1].dump}\n" } or abort "no Rails line in #{ARGV[0]}"
        src.sub!(/gem "shipit-engine", [^\n]*\n/) { "gem \"shipit-engine\", path: \"vendor/shipit-engine\"\n" }
        File.write(ARGV[0] + ".main", src + "gem \"prism\"\n")' "$d/Gemfile" "$HOME/w/rails-main"
      [ -f "$d/Gemfile.main.lock" ] || cp "$d/Gemfile.lock" "$d/Gemfile.main.lock"
      for yml in "$d"/config/database.yml; do
        grep -q reaping_frequency "$yml" ||
          sed -i 's/^\( *\)pool: \(.*\)$/\1pool: \2\n\1reaping_frequency: 0\n\1verify_timeout: 1000000/' "$yml"
      done
      for p in "$prefix" "$hprefix"; do
        [ -x "$p/bin/ruby" ] || continue
        (cd "$d" && PATH=$p/bin:$PATH BUNDLE_GEMFILE=$PWD/Gemfile.main bundle install > /tmp/bundle-$b.log 2>&1) ||
          { tail -20 /tmp/bundle-$b.log; exit 1; }
      done
    done
    ;;
  census)
    pgrep -x redis-server > /dev/null || { command -v redis-server > /dev/null || sudo apt-get install -y -qq redis-server > /dev/null; redis-server --daemonize yes --dir /tmp > /dev/null; }
    cd "$root"
    PATH=$base:$PATH script/census setup --corpus censusz3 --rails "$HOME/w/rails-main@$RAILS_SHA" --ruby "$prefix/bin" \
      --ruby-overlays fixtures/corpus/frontier-master --apps campfire,writebook
    [ -x "$hprefix/bin/ruby" ] && PATH=$base:$PATH script/census list --corpus censusz3 --ruby "$hprefix/bin" --apps campfire,writebook > /tmp/census-list-h6.log 2>&1
    # The workloads write rows; every timed process starts from this snapshot (wall_queue.sh restores it).
    for app in campfire writebook; do
      [ -d .corpus/censusz3-$app/storage.pristine ] || cp -a .corpus/censusz3-$app/storage .corpus/censusz3-$app/storage.pristine
    done
    ;;
  esac
done
