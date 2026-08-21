#!/bin/bash
# Verify that a packaged Emacs.app is self-contained: it must ship no
# third-party dynamic libraries and must link only against system libraries.
#
# Usage: verify-app.sh /path/to/Emacs.app

set -euo pipefail

app=${1:?usage: verify-app.sh /path/to/Emacs.app}
test -d "${app}"

unexpected_shared_files=$(find "${app}" \( -type f -o -type l \) \
  \( -name '*.dylib' -o -name '*.so' -o -name '*.so.*' \) -print)
if [[ -n "${unexpected_shared_files}" ]]; then
  echo "Unexpected dynamic library files in ${app}:" >&2
  echo "${unexpected_shared_files}" >&2
  exit 1
fi

non_system_libraries=$(otool -L "${app}/Contents/MacOS/Emacs" \
  | tail -n +2 | awk '{ print $1 }' \
  | grep -Ev '^(/System/Library/|/usr/lib/)' || true)
if [[ -n "${non_system_libraries}" ]]; then
  echo "Unexpected non-system dynamic libraries:" >&2
  echo "${non_system_libraries}" >&2
  exit 1
fi
