#!/bin/bash

set -euo pipefail

: "${DEPS_PREFIX:?DEPS_PREFIX must be set}"

GCC_VERSION=16.1.0
GCC_SHA256=50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79
GCC_DARWIN_PATCH_COMMIT=d1a4ad9bcd210b9721a55370d6dd67e303b7b1fb
GCC_DARWIN_PATCH_SHA256=1593153257db78c270282742088ffe961b44d793f7bbaa458895357094d6f7fc
JOBS=${JOBS:-4}

download_and_verify() {
  local url=$1
  local output=$2
  local sha256=$3

  curl --fail --location --retry 3 --output "${output}" "${url}"
  echo "${sha256}  ${output}" | shasum --algorithm 256 --check
}

gcc_tarball="gcc-${GCC_VERSION}.tar.xz"
gcc_source="gcc-${GCC_VERSION}"
darwin_patch="gcc-${GCC_VERSION}-darwin.patch"

download_and_verify \
  "https://ftpmirror.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/${gcc_tarball}" \
  "${gcc_tarball}" \
  "${GCC_SHA256}"
tar -Jxf "${gcc_tarball}"

download_and_verify \
  "https://raw.githubusercontent.com/Homebrew/homebrew-core/${GCC_DARWIN_PATCH_COMMIT}/Patches/gcc/gcc-${GCC_VERSION}.diff" \
  "${darwin_patch}" \
  "${GCC_DARWIN_PATCH_SHA256}"
patch -d "${gcc_source}" -p1 < "${darwin_patch}"
patch -d "${gcc_source}" -p1 < "${GITHUB_WORKSPACE}/patches/gcc-16-libgccjit-static.patch"

case "$(uname -m)" in
  arm64) build_cpu=aarch64 ;;
  x86_64) build_cpu=x86_64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

darwin_major=$(uname -r | cut -d. -f1)
sdk_path=$(xcrun --show-sdk-path)
mkdir "gcc-build"
cd "gcc-build"

env CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0" \
  "../${gcc_source}/configure" \
    --prefix="${DEPS_PREFIX}" \
    --libdir="${DEPS_PREFIX}/lib" \
    --build="${build_cpu}-apple-darwin${darwin_major}" \
    --enable-bootstrap \
    --disable-libstdcxx-pch \
    --disable-multilib \
    --disable-nls \
    --disable-shared \
    --enable-checking=release \
    --enable-languages=c,c++,jit \
    --with-gcc-major-version-only \
    --with-gmp="${DEPS_PREFIX}" \
    --with-isl="${DEPS_PREFIX}" \
    --with-mpc="${DEPS_PREFIX}" \
    --with-mpfr="${DEPS_PREFIX}" \
    --with-sysroot="${sdk_path}" \
    --with-system-zlib \
    --without-zstd

env CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0" \
  make -j"${JOBS}" \
    BOOT_CFLAGS="-O2 -g0" \
    BOOT_LDFLAGS="-Wl,-headerpad_max_install_names" \
    bootstrap-lean
make install

test -f "${DEPS_PREFIX}/lib/libgccjit.a"
for runtime_archive in libstdc++.a libgcc.a; do
  archive_path=$(find "${DEPS_PREFIX}" -name "${runtime_archive}" -print -quit)
  if [[ -z "${archive_path}" || ! -f "${archive_path}" ]]; then
    echo "Static GCC runtime archive was not installed: ${runtime_archive}" >&2
    exit 1
  fi
done
unexpected_dylibs=$(find "${DEPS_PREFIX}" -name '*.dylib' -print)
if [[ -n "${unexpected_dylibs}" ]]; then
  echo "Third-party dynamic libraries were produced:" >&2
  echo "${unexpected_dylibs}" >&2
  exit 1
fi
