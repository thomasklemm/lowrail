#!/usr/bin/env bash
# usage: gems.sh GEM...  Runs each gem's own suite on 4.0.9, master and master --zjit.
# Resumable: skips gem/label pairs already in ~/src/runs/gems/summary.txt; idles when done.
R409=$HOME/.local/share/mise/installs/ruby/4.0.9/bin
RM=$HOME/rubies/master/bin
out=$HOME/src/runs/gems; mkdir -p "$out"; sum=$out/summary.txt
cmd_for() {
  case $1 in
    concurrent-ruby) echo "bundle exec rake compile && bundle exec rspec spec" ;;
    nokogiri) echo "bundle exec rake compile -- --use-system-libraries && bundle exec rake test" ;;
    json|bootsnap|sqlite3|puma) echo "bundle exec rake compile && bundle exec rake test" ;;
    pg) echo "bundle exec rake compile && bundle exec rspec" ;;
    mail) echo "bundle exec rspec" ;;
    zeitwerk) echo "bundle exec minitest" ;;
    tzinfo) echo "for t in ruby_format1 ruby_format2 zoneinfo; do bundle exec ruby -Ilib -Itest test/ts_all_\$t.rb || s=1; done; exit \${s:-0}" ;;
    propshaft) echo "bin/test" ;;
    puma) echo "bundle exec rake compile && bin/test test/**/*_test.rb" ;;
    trilogy) echo "bundle exec rake compile && bundle exec rake test" ;;
    *) echo "bundle exec rake test" ;;
  esac
}
for g in "$@"; do
  dir=$HOME/src/gems/$g; [ "$g" = trilogy ] && dir=$dir/contrib/ruby
  for label in r409 master zjit; do
    grep -q "^$g $label " "$sum" 2>/dev/null && continue
    bin=$RM; opt=; [ $label = r409 ] && bin=$R409; [ $label = zjit ] && opt=--zjit
    log=$out/$g-$label.log
    start=$(date +%s)
    ( cd "$dir" && export PATH=$bin:/usr/lib/postgresql/15/bin:$PATH BUNDLE_PATH=$HOME/src/gems-bundle NOKOGIRI_USE_SYSTEM_LIBRARIES=1 &&
      git clean -qfdx -e Gemfile.lock >/dev/null 2>&1; git checkout -q -- . ;
      export BUNDLER_VERSION=$(ruby -e 'print Gem::Specification.find_by_name("bundler").version rescue print ""') ;
      bundle install -j4 > "$log.bundle" 2>&1 || { echo "BUNDLE FAILED" > "$log"; exit 97; }
      RUBYOPT=$opt timeout 2400 bash -c "$(cmd_for $g)" > "$log" 2>&1 )
    echo "$g $label status=$? secs=$(( $(date +%s) - start ))" >> "$sum"
  done
done
grep -q DONE "$sum" || echo DONE >> "$sum"
exec sleep infinity
