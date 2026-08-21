#!/bin/bash
# Build all external dependencies from upstream sources into DEPS_PREFIX as
# static libraries.  No package manager is involved; see README.md.
#
# The build is resumable: each finished dependency is recorded under
# ${DEPS_PREFIX}/.dependency-markers, so a job restored from a partial cache
# skips work that already completed.

set -euo pipefail

: "${DEPS_PREFIX:?DEPS_PREFIX must be set}"

export PATH="${DEPS_PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${DEPS_PREFIX}/lib/pkgconfig:${DEPS_PREFIX}/share/pkgconfig"
export CPPFLAGS="-I${DEPS_PREFIX}/include"
export LDFLAGS="-L${DEPS_PREFIX}/lib"

marker_dir="${DEPS_PREFIX}/.dependency-markers"
mkdir -p "${DEPS_PREFIX}" "${marker_dir}"

built() { [[ -f "${marker_dir}/$1" ]]; }
mark_built() { touch "${marker_dir}/$1"; }

fetch() {
  curl -fLO "$1" --retry 3
  tar -xf "$(basename "$1")"
}

# build_autotools NAME URL SRCDIR [CONFIGURE_FLAGS...]
build_autotools() {
  local name=$1 url=$2 srcdir=$3
  shift 3
  built "${name}" && return 0
  fetch "${url}"
  (cd "${srcdir}" && ./configure --prefix="${DEPS_PREFIX}" "$@" && make -j4 && make install)
  mark_built "${name}"
}

build_autotools m4 https://ftpmirror.gnu.org/gnu/m4/m4-1.4.21.tar.xz m4-1.4.21
build_autotools autoconf https://ftpmirror.gnu.org/gnu/autoconf/autoconf-2.73.tar.xz autoconf-2.73
build_autotools automake https://ftpmirror.gnu.org/gnu/automake/automake-1.18.1.tar.xz automake-1.18.1
build_autotools libtool https://ftpmirror.gnu.org/gnu/libtool/libtool-2.6.2.tar.xz libtool-2.6.2 --disable-shared
if ! built pkgconf; then
  fetch https://github.com/pkgconf/pkgconf/archive/refs/tags/pkgconf-3.0.3.tar.gz
  (cd pkgconf-pkgconf-3.0.3 && ./autogen.sh \
    && ./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4 && make install)
  ln -sf "${DEPS_PREFIX}/bin/pkgconf" "${DEPS_PREFIX}/bin/pkg-config"
  mark_built pkgconf
fi
build_autotools texinfo https://ftpmirror.gnu.org/gnu/texinfo/texinfo-7.3.tar.xz texinfo-7.3
build_autotools libiconv https://ftpmirror.gnu.org/gnu/libiconv/libiconv-1.19.tar.gz libiconv-1.19 --disable-shared
build_autotools libunistring https://ftpmirror.gnu.org/gnu/libunistring/libunistring-1.4.2.tar.xz libunistring-1.4.2 --disable-shared
build_autotools gettext https://ftpmirror.gnu.org/gnu/gettext/gettext-1.0.tar.xz gettext-1.0 --disable-shared
if ! built ncurses; then
  fetch https://ftpmirror.gnu.org/gnu/ncurses/ncurses-6.6.tar.gz
  (cd ncurses-6.6 && ./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4 && make install)
  ln -sf "${DEPS_PREFIX}/include/ncursesw/curses.h" "${DEPS_PREFIX}/include/ncurses.h"
  mark_built ncurses
fi
build_autotools zlib https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.xz zlib-1.3.2 --static
build_autotools libxml2 https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz libxml2-2.15.3 --disable-shared
build_autotools gmp https://ftpmirror.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz gmp-6.3.0 --disable-shared
build_autotools nettle https://ftpmirror.gnu.org/gnu/nettle/nettle-4.0.tar.gz nettle-4.0 --disable-shared
build_autotools libidn2 https://ftpmirror.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz libidn2-2.3.8 --disable-shared
build_autotools gnutls https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz gnutls-3.8.13 \
  --disable-shared --with-included-libtasn1 --without-p11-kit
if ! built tree-sitter; then
  fetch https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.26.11.tar.gz
  (cd tree-sitter-0.26.11 && make -j4 && make install PREFIX="${DEPS_PREFIX}")
  find "${DEPS_PREFIX}/lib" -name 'libtree-sitter*.dylib' -delete
  mark_built tree-sitter
fi
build_autotools sqlite https://www.sqlite.org/2026/sqlite-autoconf-3530100.tar.gz sqlite-autoconf-3530100 --disable-shared
build_autotools gzip https://ftpmirror.gnu.org/gnu/gzip/gzip-1.14.tar.xz gzip-1.14

touch "${DEPS_PREFIX}/.built"
