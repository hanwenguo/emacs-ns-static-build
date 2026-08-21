#!/bin/bash
# Build all external dependencies from upstream sources into DEPS_PREFIX as
# static libraries.  No package manager is involved; see README.md.

set -euo pipefail

: "${DEPS_PREFIX:?DEPS_PREFIX must be set}"

export PATH="${DEPS_PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${DEPS_PREFIX}/lib/pkgconfig:${DEPS_PREFIX}/share/pkgconfig"
export CPPFLAGS="-I${DEPS_PREFIX}/include"
export LDFLAGS="-L${DEPS_PREFIX}/lib"

mkdir -p "${DEPS_PREFIX}"

curl -fLO https://ftpmirror.gnu.org/gnu/m4/m4-1.4.21.tar.xz --retry 3
tar -Jxf m4-1.4.21.tar.xz && cd m4-1.4.21
./configure --prefix="${DEPS_PREFIX}" && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/autoconf/autoconf-2.73.tar.xz --retry 3
tar -Jxf autoconf-2.73.tar.xz && cd autoconf-2.73
./configure --prefix="${DEPS_PREFIX}" && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/automake/automake-1.18.1.tar.xz --retry 3
tar -Jxf automake-1.18.1.tar.xz && cd automake-1.18.1
./configure --prefix="${DEPS_PREFIX}" && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/libtool/libtool-2.6.2.tar.xz --retry 3
tar -Jxf libtool-2.6.2.tar.xz && cd libtool-2.6.2
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://github.com/pkgconf/pkgconf/archive/refs/tags/pkgconf-3.0.3.tar.gz --retry 3
tar -zxf pkgconf-3.0.3.tar.gz && cd pkgconf-pkgconf-3.0.3
./autogen.sh && ./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
ln -sf "${DEPS_PREFIX}/bin/pkgconf" "${DEPS_PREFIX}/bin/pkg-config"
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/texinfo/texinfo-7.3.tar.xz --retry 3
tar -Jxf texinfo-7.3.tar.xz && cd texinfo-7.3
./configure --prefix="${DEPS_PREFIX}" && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/libiconv/libiconv-1.19.tar.gz --retry 3
tar -zxf libiconv-1.19.tar.gz && cd libiconv-1.19
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/libunistring/libunistring-1.4.2.tar.xz --retry 3
tar -Jxf libunistring-1.4.2.tar.xz && cd libunistring-1.4.2
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/gettext/gettext-1.0.tar.xz --retry 3
tar -Jxf gettext-1.0.tar.xz && cd gettext-1.0
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/ncurses/ncurses-6.6.tar.gz --retry 3
tar -zxf ncurses-6.6.tar.gz && cd ncurses-6.6
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
ln -sf "${DEPS_PREFIX}/include/ncursesw/curses.h" "${DEPS_PREFIX}/include/ncurses.h"
cd ..
curl -fLO https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.xz --retry 3
tar -Jxf zlib-1.3.2.tar.xz && cd zlib-1.3.2
./configure --static --prefix="${DEPS_PREFIX}" && make -j4
make install
cd ..
curl -fO https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz --retry 3
tar -Jxf libxml2-2.15.3.tar.xz && cd libxml2-2.15.3
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz --retry 3
tar -Jxf gmp-6.3.0.tar.xz && cd gmp-6.3.0
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/nettle/nettle-4.0.tar.gz --retry 3
tar -zxf nettle-4.0.tar.gz && cd nettle-4.0
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz --retry 3
tar -zxf libidn2-2.3.8.tar.gz && cd libidn2-2.3.8
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fO https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz --retry 3
tar -Jxf gnutls-3.8.13.tar.xz && cd gnutls-3.8.13
./configure --prefix="${DEPS_PREFIX}" --disable-shared --with-included-libtasn1 --without-p11-kit && make -j4
make install
cd ..
curl -fLO https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.26.11.tar.gz --retry 3
tar -zxf v0.26.11.tar.gz && cd tree-sitter-0.26.11
make -j4
make install PREFIX="${DEPS_PREFIX}"
find "${DEPS_PREFIX}/lib" -name 'libtree-sitter*.dylib' -delete
cd ..
curl -fO https://www.sqlite.org/2026/sqlite-autoconf-3530100.tar.gz --retry 3
tar -zxf sqlite-autoconf-3530100.tar.gz && cd sqlite-autoconf-3530100
./configure --prefix="${DEPS_PREFIX}" --disable-shared && make -j4
make install
cd ..
curl -fLO https://ftpmirror.gnu.org/gnu/gzip/gzip-1.14.tar.xz --retry 3
tar -Jxf gzip-1.14.tar.xz && cd gzip-1.14
./configure --prefix="${DEPS_PREFIX}" && make -j4
make install
cd ..
touch "${DEPS_PREFIX}/.built"
