#!/bin/bash
# Orb prerequisites for round-app-suites.yml (docs/upstream/readiness.md), idempotent: database and image packages
# with their system services disabled (services.rb starts them as orb services), pgvector 0.8.1 for PostgreSQL 15,
# libvips 8.18.7 in /usr/local (Discourse's vips worker refuses older), the apps' Rubies, Node 22 for Forem, and
# Chrome for Testing as /usr/bin/google-chrome for the system specs.
set -euo pipefail
build=${READINESS_BUILD:-$HOME/src/readiness-build}
mkdir -p "$build"

if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
  sudo install -d /usr/share/postgresql-common/pgdg
  sudo curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" |
    sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null
fi
packages=(postgresql-15 postgresql-18 postgresql-server-dev-15 postgresql-contrib redis-server memcached
  libpq-dev libidn11-dev libicu-dev libjemalloc2 libjemalloc-dev imagemagick ffmpeg libvips-dev
  gifsicle jpegoptim optipng pngquant meson ninja-build libglib2.0-dev libexpat1-dev libjpeg-dev libpng-dev
  libwebp-dev libtiff-dev libexif-dev liblcms2-dev libheif-dev libgif-dev librsvg2-dev libimagequant-dev
  libhwy-dev libarchive-dev libcgif-dev libspng-dev)
missing=()
for p in "${packages[@]}"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' || missing+=("$p"); done
if ((${#missing[@]})); then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
fi
for s in postgresql redis-server memcached; do sudo systemctl disable --now "$s" >/dev/null 2>&1 || true; done

if [ ! -f /usr/lib/postgresql/15/lib/vector.so ]; then
  rm -rf "$build/pgvector" && git clone -q --depth 1 --branch v0.8.1 https://github.com/pgvector/pgvector "$build/pgvector"
  make -C "$build/pgvector" -s -j"$(nproc)" PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
  sudo make -C "$build/pgvector" -s install PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
fi

if [ "$(/usr/local/bin/vips --version 2>/dev/null)" != "vips-8.18.7" ]; then
  (cd "$build" && curl -fsSLO https://github.com/libvips/libvips/releases/download/v8.18.7/vips-8.18.7.tar.xz &&
    rm -rf vips-8.18.7 && tar xf vips-8.18.7.tar.xz && cd vips-8.18.7 &&
    meson setup build --prefix=/usr/local --buildtype=release -Dintrospection=disabled -Dmodules=disabled >/dev/null &&
    ninja -C build >/dev/null && sudo ninja -C build install >/dev/null && sudo ldconfig)
fi

for v in 4.0.9 3.4.12 3.4.9 3.4.4 3.3.13; do MISE_RUBY_COMPILE=false mise install -q "ruby@$v"; done
MISE_NODE_COMPILE=false mise install -q node@22

chrome=$(ls -d "$HOME"/.agent-browser/browsers/chrome-*/chrome 2>/dev/null | sort -V | tail -1)
if [ -n "$chrome" ] && [ "$(readlink -f /usr/bin/google-chrome 2>/dev/null)" != "$chrome" ]; then
  sudo ln -sf "$chrome" /usr/bin/google-chrome
fi
echo "app-suite prerequisites ready (vips $(/usr/local/bin/vips --version), $(google-chrome --version 2>/dev/null || echo 'no Chrome'))"
