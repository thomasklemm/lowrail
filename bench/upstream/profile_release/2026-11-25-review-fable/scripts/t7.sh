#!/usr/bin/env bash
# t7.sh APPDIR RUBY : disk use of --out during and after a profile, with and without --keep-runs; the report
# rebuilt from kept runs; what the path table saves against writing each path in every row (format 2).
set -uo pipefail
app=$1; . "$(dirname "$0")/env.sh" "$2"; cd "$app"
for keep in "" "--keep-runs"; do
  out=tmp/lp-t7${keep:+-kept}; rm -rf "$out"; peak=0
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --out "$out" $keep -- bin/rails test > /tmp/pr/t7.log 2>&1 & pid=$!
  while kill -0 $pid 2>/dev/null; do s=$(du -sb "$out" 2>/dev/null | cut -f1); [ "${s:-0}" -gt "$peak" ] && peak=$s; sleep 0.1; done
  wait $pid; echo "keep='$keep' exit $? peak $peak bytes, after $(du -sb "$out" | cut -f1) bytes: $(ls -A "$out" | tr '\n' ' ')"
done
cd tmp/lp-t7-kept
for f in run*/*.tsv; do
  ruby -e 'rows = File.readlines(ARGV[0], chomp: true); paths = {}; expanded = 0
    rows.each do |r|
      f = r.split("\t")
      case f[0]
      when "P" then paths[f[1]] = f[2]
      when "@" then expanded += r.bytesize + 1 - f[3].bytesize - f[5].bytesize + paths.fetch(f[3], "-").bytesize + paths.fetch(f[5], "-").bytesize
      when "A", "G", /\A#/ then expanded += r.bytesize + 1
      else expanded += r.bytesize + 1 - f[0].bytesize + paths.fetch(f[0], "-").bytesize
      end
    end
    size = File.size(ARGV[0]); puts "#{ARGV[0]}: #{size} bytes with the path table, #{expanded} with a path in every row (#{(expanded.fdiv(size)).round(1)}x), #{paths.size} paths, #{rows.count { _1.start_with?("@") }} attribution rows"' "$f"
done
sha256sum report.json report.md > /tmp/pr/t7-before.sha; cd ../..
bundle exec lowrail-profile report tmp/lp-t7-kept > /dev/null; echo "report from kept runs: exit $?"; (cd tmp/lp-t7-kept && sha256sum -c /tmp/pr/t7-before.sha)
bundle exec lowrail-profile report tmp/lp-t7 2>&1 | tail -1; echo "report without runs: exit $?"
bundle exec lowrail-profile report 2>&1 | tail -1 | cut -c1-200; echo "report (default dir): exit ${PIPESTATUS[0]}"
git status --porcelain
