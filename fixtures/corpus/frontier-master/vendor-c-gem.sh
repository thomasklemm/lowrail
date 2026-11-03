#!/usr/bin/env bash
# vendor-c-gem.sh NAME VERSION PATCH EXTDIR SO [LABEL]: vendors the source gem
# NAME-VERSION with PATCH (a file next to this script; - for none) as a path gem in
# vendor/f1/NAME, builds its C extension in EXTDIR with the target Ruby, copies
# it to lib/SO, and points the app's Gemfile at it (replacing the app's own gem
# line, or adding one for a transitive dependency, require: false). Runs in the
# app directory with the target Ruby first on PATH; idempotent.
set -euo pipefail
name=$1; version=$2; patch=$3; extdir=$4; so=$5; label=${6:-$patch}
here=$(cd "$(dirname "$0")" && pwd)
dest=vendor/f1/$name
if [ ! -f "$dest/lib/$so" ]; then
  tmp=$(mktemp -d)
  (cd "$tmp" && gem fetch "$name" -v "$version" --platform ruby --quiet >/dev/null && gem unpack "$name-$version.gem" >/dev/null &&
    gem spec "$name-$version.gem" --ruby > "$name-$version/$name.gemspec")
  rm -rf "$dest"; mkdir -p vendor/f1; mv "$tmp/$name-$version" "$dest"; rm -rf "$tmp"
  [ "$patch" = - ] || patch -d "$dest" -p1 -s -i "$here/$patch"
  (cd "$dest/$extdir" && ruby extconf.rb >/dev/null && make -s -j4 >/dev/null 2>&1 && cp "$(basename "$so")" "../../lib/$so")
fi
line="gem \"$name\", path: \"vendor/f1/$name\", require: false # frontier-master: patched gem ($label)"
if grep -qF "path: \"vendor/f1/$name\"" Gemfile; then exit 0; fi
if grep -qE "^\s*gem [\"']$name[\"']" Gemfile; then
  # An app line with require: (cbor: require: false) keeps require: false; a plain line (rinku) stays required.
  if grep -qE "^\s*gem [\"']$name[\"'].*require:" Gemfile; then
    sed -i -E "s|^\s*gem [\"']$name[\"'](.*)$|$line|" Gemfile
  else
    sed -i -E "s|^\s*gem [\"']$name[\"'].*$|gem \"$name\", path: \"vendor/f1/$name\" # frontier-master: patched gem ($label)|" Gemfile
  fi
else
  printf '\n%s\n' "$line" >> Gemfile
fi
