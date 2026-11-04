#!/usr/bin/env bash
# Callgrind Ir per DocumentFragment#css for the nokogiri candidate (docs/upstream/gem-request-census-2.md): base, base
# again (A/A), branch, on one Ruby. BASE and BRANCH are nokogiri lib directories with the extension compiled for that
# Ruby; EXTRA_I adds loofah's and crass's lib directories.
#   RUBY_BIN=... [RUBYFLAGS=--yjit] EXTRA_I="-I.../loofah/lib -I.../crass/lib" bash nokogiri_ir.sh BASE BRANCH
here=$(cd "$(dirname "$0")" && pwd)
for expr in 'NOKO.css("action-text-attachment")' 'LOOFAH.css("action-text-attachment")'; do
  line="$expr:"
  for lib in "$1" "$1" "$2"; do
    line="$line $(RUBYFLAGS="${RUBYFLAGS:-} -I$lib ${EXTRA_I:-}" bash "$here/../gem_request_census/ir_region.sh" \
      "$here/nokogiri_setup.rb" "$expr" 2000 500)"
  done
  echo "$line"
done
