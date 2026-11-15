#!/usr/bin/env bash
# Checks that probe.rb catches plausible wrong versions of the UA1 changes: each mutant is applied to a
# useragent checkout, the probe runs over CORPUS, and the lines that differ from main's output are counted.
#   mutants.sh RUBY_BIN MUTANT_UA_DIR MUTANT_GEMFILE_DIR MAIN_GEMFILE_DIR CORPUS
# MUTANT_UA_DIR is a useragent checkout with patches/0001 applied (the fast path the first two mutants edit).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
bin=$1 ua=$2 mut=$3 main=$4 corpus=$5
probe() { BUNDLE_GEMFILE=$1/Gemfile PATH="$bin:$PATH" "$bin/ruby" -rbundler/setup "$here/probe.rb" "$corpus"; }
probe "$main" > /tmp/ua1-mut-main.txt
mutate() { # name, file, ruby code that edits the source text in s
  git -C "$ua" checkout -q -- .
  "$bin/ruby" -e 'f = ARGV[0]; s = File.read(f); t = s.dup; eval(ARGV[1]); abort "no change: #{f}" if s == t; File.write(f, s)' "$ua/$2" "$3"
  probe "$mut" > /tmp/ua1-mut.txt
  echo "$1: $(diff <(cat /tmp/ua1-mut-main.txt) /tmp/ua1-mut.txt | grep -c '^>') of $(wc -l < /tmp/ua1-mut.txt) lines differ"
}
mutate "fast path accepts any digits and dots" lib/user_agent/version.rb 's.sub!("/\\A\\d+(?:\\.\\d+)*\\z/", "/\\A[\\d.]+\\z/")'
mutate "fast path anchored per line" lib/user_agent/version.rb 's.sub!("/\\A\\d+(?:\\.\\d+)*\\z/", "/^\\d+(?:\\.\\d+)*$/")'
mutate "detect_product with casecmp?" lib/user_agent/browsers/base.rb 's.sub!("useragent.product.to_s.downcase == product.to_s.downcase", "useragent.product.to_s.casecmp?(product.to_s)")'
mutate "Chrome#application memoized" lib/user_agent/browsers/chrome.rb 's.sub!("self.reject", "@application ||= self.reject")'
git -C "$ua" checkout -q -- . && git -C "$ua" apply "$here/mutant-lazy-version.patch" && probe "$mut" > /tmp/ua1-mut.txt &&
  echo "Version parsed lazily: $(diff /tmp/ua1-mut-main.txt /tmp/ua1-mut.txt | grep -c '^>') of $(wc -l < /tmp/ua1-mut.txt) lines differ"
mutate "AppleCoreMedia#application is first" lib/user_agent/browsers/apple_core_media.rb 's.sub!("self.reject { |agent| agent.comment.nil? || agent.comment.empty? }.first", "first")'
mutate "extend? skips IE" lib/user_agent/browsers.rb 's.sub!("all.each do |extension|", "(all - [InternetExplorer]).each do |extension|")'
git -C "$ua" checkout -q -- .
