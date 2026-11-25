#!/usr/bin/env bash
# tree.sh APPDIR: status and content hashes of every tracked or unignored file, plus the ignored-path list
cd "$1" || exit 2
git status --porcelain=v1 -uall
git ls-files -co --exclude-standard -z | xargs -0 sha256sum 2>/dev/null | sort -k2
echo "--- ignored (paths only, outside tmp/lowrail-profile)"
git status --porcelain=v1 --ignored -unormal | grep '^!!' | grep -v 'tmp/lowrail-profile' | sort
