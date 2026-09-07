#!/bin/bash
# Expand a ftpmirror.gnu.org URL into the same file on each known GNU mirror.
#
# ftpmirror.gnu.org is the redirector GNU asks downloaders to use, so it stays
# first.  But when it breaks it breaks for every path at once -- it has
# returned 502/504 for, or simply hung on, all GNU tarballs for hours at a
# time, which failed the whole dependency build -- so fall back to the
# canonical host and then to a large mirror.

GNU_MIRRORS=(
  https://ftpmirror.gnu.org/gnu
  https://ftp.gnu.org/gnu
  https://mirrors.kernel.org/gnu
)

# gnu_mirror_urls URL -- print the candidate URLs to try, in order.  A URL that
# is not a GNU one is printed unchanged, so callers can route every download
# through this.
gnu_mirror_urls() {
  local url=$1
  if [[ ${url} != https://ftpmirror.gnu.org/gnu/* ]]; then
    printf '%s\n' "${url}"
    return 0
  fi
  local path=${url#https://ftpmirror.gnu.org/gnu/}
  local mirror
  for mirror in "${GNU_MIRRORS[@]}"; do
    printf '%s\n' "${mirror}/${path}"
  done
}
