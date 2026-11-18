#!/usr/bin/env bash
# guard_mutants.sh RACK: applies each guard mutant to a copy of RACK (unescape-cgi-3) and runs spec_utils and spec_query_parser;
# old_lib-REV lines run the same tests against another revision's lib.
rack=$1; tmp=$(mktemp -d); cp -r "$rack"/. "$tmp"; cd "$tmp"
U=lib/rack/utils.rb Q=lib/rack/query_parser.rb
E='unless s.instance_of?(String) \&\& s.encoding.ascii_compatible?$'
mut() { # name file sed-expr [file sed-expr]
  name=$1; shift; /usr/bin/git checkout -q -- lib
  while (($#)); do sed -i "$2" "$1"; shift 2; done
  out=$(CI=spec bundle exec ruby -Ilib -Itest -e 'ARGV.each { |f| require f }' ./test/spec_utils.rb ./test/spec_query_parser.rb 2>&1 | grep -E '^[0-9]+ runs')
  printf '%-34s %s\n' "$name" "$out"
}
esc='/def escape(s)$/,/^    end/'; une='/def unescape(s, encoding/,/^    end/'; qp='/def unescape(string/,/^    end/'
mut none $U 's/x/x/'
mut escape-no-guard $U "${esc}{/return URI.encode/d}"
mut unescape-no-guard $U "${une}{/return URI.decode/d}"
mut qp-no-guard $Q "${qp}{/return URI.decode/d}"
mut decoders-no-guard $U "${une}{/return URI.decode/d}" $Q "${qp}{/return URI.decode/d}"
mut escape-no-ascii $U "${esc}{s/ \&\& s.encoding.ascii_compatible?//}"
mut unescape-no-ascii $U "${une}{s/ \&\& s.encoding.ascii_compatible?//}"
mut qp-no-ascii $Q "${qp}{s/ \&\& string.encoding.ascii_compatible?//}"
mut escape-String=== $U "${esc}{s/s.instance_of?(String)/String === s/}"
mut unescape-String=== $U "${une}{s/s.instance_of?(String)/String === s/}"
mut qp-String=== $Q "${qp}{s/string.instance_of?(String)/String === string/}"
mut all-String=== $U 's/s.instance_of?(String)/String === s/' $Q 's/string.instance_of?(String)/String === string/'
mut all-is_a $U 's/s.instance_of?(String)/s.is_a?(String)/' $Q 's/string.instance_of?(String)/string.is_a?(String)/'
for rev in 178bfa8392 02087583dc da90464e3f; do
  /usr/bin/git checkout -q "$rev" -- lib 2>/dev/null || { /usr/bin/git fetch -q origin "$rev" && /usr/bin/git checkout -q "$rev" -- lib; }
  printf '%-34s %s\n' "old_lib-$rev" "$(CI=spec bundle exec ruby -Ilib -Itest -e 'ARGV.each { |f| require f }' ./test/spec_utils.rb ./test/spec_query_parser.rb 2>&1 | grep -E '^[0-9]+ runs')"
done
rm -rf "$tmp"
