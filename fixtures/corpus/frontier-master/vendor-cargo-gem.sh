#!/usr/bin/env bash
# vendor-cargo-gem.sh NAME VERSION SO: vendors the source gem NAME-VERSION with
# NAME-VERSION-magnus-0.8.4.patch as a path gem in vendor/f1/NAME, builds its
# Rust extension into lib/SO, and points the Gemfile at it. The patches only
# move magnus 0.8.2 -> 0.8.4 in Cargo.lock (0.8.2's rb_data_type_t binding lacks
# master's new handle_weak_references field), plus whatever rb-sys needs for 4.1
# (see the patch). Runs in the app directory with the target Ruby first on
# PATH; idempotent.
set -euo pipefail
name=$1; version=$2; so=$3
here=$(cd "$(dirname "$0")" && pwd)
dest=vendor/f1/$name
if [ ! -f "$dest/lib/$so" ]; then
  tmp=$(mktemp -d)
  (cd "$tmp" && gem fetch "$name" -v "$version" --platform ruby --quiet >/dev/null && gem unpack "$name-$version.gem" >/dev/null &&
    gem spec "$name-$version.gem" --ruby > "$name-$version/$name.gemspec")
  rm -rf "$dest"; mkdir -p vendor/f1; mv "$tmp/$name-$version" "$dest"; rm -rf "$tmp"
  patch -d "$dest" -p1 -s -i "$here/$name-$version-magnus-0.8.4.patch"
  (cd "$dest" && cargo build --quiet --release && cp target/release/lib*.so "lib/$so" && rm -rf target)
fi
line="gem \"$name\", path: \"vendor/f1/$name\", require: false # frontier-master: patched gem (magnus 0.8.4)"
if grep -qF "path: \"vendor/f1/$name\"" Gemfile; then exit 0; fi
if grep -qE "^\s*gem [\"']$name[\"']" Gemfile; then
  sed -i -E "s|^\s*gem [\"']$name[\"'].*$|$line|" Gemfile
else
  printf '\n%s\n' "$line" >> Gemfile
fi
