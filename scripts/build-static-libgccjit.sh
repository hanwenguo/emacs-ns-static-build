#!/bin/bash
# Build GCC (C, C++, jit) from source and install a fully self-contained
# static libgccjit.a into DEPS_PREFIX.
#
# GCC's jit language normally requires --enable-host-shared and ships a
# dylib; patches/gcc-16-libgccjit-static.patch teaches the Darwin build to
# also produce libgccjit.a.  That archive still references GCC's support
# libraries and defines libiberty symbols (xmalloc and friends) that clash
# with Emacs, so after installation it is folded together with everything
# it needs (libstdc++, libgcc, GMP, MPFR, MPC, ISL, zlib, libiconv) into a
# single relocatable object whose only external symbols are the gcc_jit_*
# API.  Linking that archive into Emacs needs no extra libraries and cannot
# conflict with Emacs symbols, on any Emacs branch.
#
# Like build-deps.sh, this script is resumable: the downloaded tarball,
# patched source tree, and configured build directory are reused when
# restored from a partial cache, and make continues where it stopped.

set -euo pipefail

: "${DEPS_PREFIX:?DEPS_PREFIX must be set}"

GCC_VERSION=16.1.0
GCC_SHA256=50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79
GCC_DARWIN_PATCH_COMMIT=d1a4ad9bcd210b9721a55370d6dd67e303b7b1fb
GCC_DARWIN_PATCH_SHA256=1593153257db78c270282742088ffe961b44d793f7bbaa458895357094d6f7fc
JOBS=${JOBS:-4}

repo_root=$(cd "$(dirname "$0")/.." && pwd)

download_and_verify() {
  local url=$1
  local output=$2
  local sha256=$3

  curl --fail --location --retry 3 --output "${output}" "${url}"
  echo "${sha256}  ${output}" | shasum --algorithm 256 --check
}

gcc_work_root="${DEPS_PREFIX}/.gcc-work"
gcc_tarball="${gcc_work_root}/gcc-${GCC_VERSION}.tar.xz"
gcc_source="${gcc_work_root}/gcc-${GCC_VERSION}"
gcc_build="${gcc_work_root}/gcc-build"
darwin_patch="${gcc_work_root}/gcc-${GCC_VERSION}-darwin.patch"
source_ready="${gcc_source}/.patches-applied"
mkdir -p "${gcc_work_root}"

if [[ -f "${gcc_tarball}" ]]; then
  echo "${GCC_SHA256}  ${gcc_tarball}" | shasum --algorithm 256 --check
else
  download_and_verify \
    "https://ftpmirror.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" \
    "${gcc_tarball}" \
    "${GCC_SHA256}"
fi

if [[ -f "${darwin_patch}" ]]; then
  echo "${GCC_DARWIN_PATCH_SHA256}  ${darwin_patch}" | shasum --algorithm 256 --check
else
  download_and_verify \
    "https://raw.githubusercontent.com/Homebrew/homebrew-core/${GCC_DARWIN_PATCH_COMMIT}/Patches/gcc/gcc-${GCC_VERSION}.diff" \
    "${darwin_patch}" \
    "${GCC_DARWIN_PATCH_SHA256}"
fi

if [[ ! -f "${source_ready}" ]]; then
  test "${gcc_source}" = "${gcc_work_root}/gcc-${GCC_VERSION}"
  rm -rf -- "${gcc_source}"
  tar -C "${gcc_work_root}" -Jxf "${gcc_tarball}"
  patch -d "${gcc_source}" -p1 < "${darwin_patch}"
  patch -d "${gcc_source}" -p1 < "${repo_root}/patches/gcc-16-libgccjit-static.patch"
  touch "${source_ready}"
fi

case "$(uname -m)" in
  arm64) build_cpu=aarch64 ;;
  x86_64) build_cpu=x86_64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

darwin_major=$(uname -r | cut -d. -f1)
sdk_path=$(xcrun --show-sdk-path)
if [[ ! -f "${gcc_build}/Makefile" ]]; then
  test "${gcc_build}" = "${gcc_work_root}/gcc-build"
  rm -rf -- "${gcc_build}"
  mkdir -p "${gcc_build}"
  cd "${gcc_build}"
  env CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0" \
    "${gcc_source}/configure" \
      --prefix="${DEPS_PREFIX}" \
      --libdir="${DEPS_PREFIX}/lib" \
      --build="${build_cpu}-apple-darwin${darwin_major}" \
      --enable-bootstrap \
      --disable-libstdcxx-pch \
      --disable-multilib \
      --disable-nls \
      --enable-shared \
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
fi

cd "${gcc_build}"

env CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0" \
  make -j"${JOBS}" \
    BOOT_CFLAGS="-O2 -g0" \
    BOOT_LDFLAGS="-Wl,-headerpad_max_install_names" \
    bootstrap-lean
make install

test -f "${DEPS_PREFIX}/lib/libgccjit.a"

# The GCC runtime archives are bundled into Emacs.app so the embedded
# driver can link .eln files on user machines.
for runtime_archive in libgcc.a libemutls_w.a libheapt_w.a; do
  archive_path=$(find "${DEPS_PREFIX}/lib" -name "${runtime_archive}" -print -quit)
  if [[ -z "${archive_path}" || ! -f "${archive_path}" ]]; then
    echo "Static GCC runtime archive was not installed: ${runtime_archive}" >&2
    exit 1
  fi
done

# Fold libgccjit.a into a single self-contained relocatable object exporting
# only the gcc_jit_* API.  make install above always rewrites a pristine
# libgccjit.a, so this is safe to re-run after a resumed build.
#
# The merge is seeded with -u for every gcc_jit_* symbol rather than
# -all_load: the archive contains mutually exclusive alternates (ggc-page.o
# vs ggc-none.o, two hash-table.o members) that force-loading everything
# would collide, while on-demand loading picks one of each, exactly as the
# upstream libgccjit dylib link does.
libstdcxx_archive=$(find "${DEPS_PREFIX}/lib" -name 'libstdc++.a' -type f -print -quit)
libgcc_archive=$(find "${DEPS_PREFIX}/lib" -name 'libgcc.a' -type f -print -quit)
test -f "${libstdcxx_archive}"
test -f "${libgcc_archive}"
fold_dir="${gcc_work_root}/fold"
rm -rf -- "${fold_dir}"
mkdir -p "${fold_dir}"
# GMP leaves one tentative definition (__gmp_junk, a write-only junk sink)
# as a common symbol.  Commons survive -exported_symbols_list as private
# externals and would still tentatively merge with Emacs's own GMP at the
# final link; a real zero definition absorbs the common here so it is
# hidden like every other internal symbol.
printf 'long __gmp_junk;\n' > "${fold_dir}/gmp-junk-shim.c"
/usr/bin/clang -c -fno-common "${fold_dir}/gmp-junk-shim.c" \
  -o "${fold_dir}/gmp-junk-shim.o"
api_symbols="${fold_dir}/api-symbols"
/usr/bin/nm -gU "${DEPS_PREFIX}/lib/libgccjit.a" \
  | awk 'NF == 3 { print $3 }' | grep '^_gcc_jit_' | sort -u > "${api_symbols}"
test -s "${api_symbols}"
u_flags=()
while IFS= read -r symbol; do
  u_flags+=("-Wl,-u,${symbol}")
done < "${api_symbols}"
/usr/bin/clang -r -nostdlib \
  "${u_flags[@]}" \
  -Wl,-exported_symbols_list,"${repo_root}/patches/libgccjit-api.exp" \
  "${DEPS_PREFIX}/lib/libgccjit.a" \
  "${libstdcxx_archive}" \
  "${libgcc_archive}" \
  "${DEPS_PREFIX}/lib/libgmp.a" \
  "${DEPS_PREFIX}/lib/libmpfr.a" \
  "${DEPS_PREFIX}/lib/libmpc.a" \
  "${DEPS_PREFIX}/lib/libisl.a" \
  "${DEPS_PREFIX}/lib/libz.a" \
  "${DEPS_PREFIX}/lib/libiconv.a" \
  "${fold_dir}/gmp-junk-shim.o" \
  -o "${fold_dir}/libgccjit-folded.o"
rm -f "${DEPS_PREFIX}/lib/libgccjit.a"
/usr/bin/libtool -static -o "${DEPS_PREFIX}/lib/libgccjit.a" \
  "${fold_dir}/libgccjit-folded.o"

stray_symbols=$(/usr/bin/nm -gU "${DEPS_PREFIX}/lib/libgccjit.a" \
  | awk 'NF == 3 { print $3 }' | grep -v '^_gcc_jit_' || true)
if [[ -n "${stray_symbols}" ]]; then
  echo "Folded libgccjit.a exports symbols outside the gcc_jit_* API:" >&2
  echo "${stray_symbols}" >&2
  exit 1
fi
/usr/bin/nm -gU "${DEPS_PREFIX}/lib/libgccjit.a" \
  | awk 'NF == 3 { print $3 }' | grep '^_gcc_jit_' | sort -u > "${fold_dir}/folded-symbols"
if ! diff -u "${api_symbols}" "${fold_dir}/folded-symbols" >&2; then
  echo "Folded libgccjit.a does not export the complete gcc_jit_* API" >&2
  exit 1
fi

# The folded archive must link into a plain C program with no additional
# libraries; anything unresolved here would also break the Emacs link.
cat > "${fold_dir}/smoke.c" << 'EOF'
#include <libgccjit.h>

int
main (void)
{
  gcc_jit_context *ctxt = gcc_jit_context_acquire ();
  if (!ctxt)
    return 1;
  gcc_jit_context_release (ctxt);
  return 0;
}
EOF
/usr/bin/clang -I"${DEPS_PREFIX}/include" "${fold_dir}/smoke.c" \
  "${DEPS_PREFIX}/lib/libgccjit.a" -o "${fold_dir}/smoke"
"${fold_dir}/smoke"

find "${DEPS_PREFIX}" \( -type f -o -type l \) \
  \( -name '*.dylib' -o -name '*.so' -o -name '*.so.*' \) -print -delete
unexpected_shared_libraries=$(find "${DEPS_PREFIX}" \( -type f -o -type l \) \
  \( -name '*.dylib' -o -name '*.so' -o -name '*.so.*' \) -print)
if [[ -n "${unexpected_shared_libraries}" ]]; then
  echo "Third-party dynamic libraries were produced:" >&2
  echo "${unexpected_shared_libraries}" >&2
  exit 1
fi
test "${gcc_work_root}" = "${DEPS_PREFIX}/.gcc-work"
cd "${DEPS_PREFIX}"
rm -rf -- "${gcc_work_root}"
