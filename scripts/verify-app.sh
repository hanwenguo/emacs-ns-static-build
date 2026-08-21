#!/bin/bash
# Verify that a packaged Emacs.app is self-contained: it must ship no
# third-party dynamic libraries, must link only against system libraries,
# and must be able to native-compile, load, and run an .eln without any
# build-machine paths or environment.
#
# Usage: verify-app.sh /path/to/Emacs.app
#
# If DEPS_PREFIX is set, the directory is renamed away for the duration of
# the native-compilation smoke test so nothing can silently resolve
# against the build prefix.

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

# Native-compilation smoke test, in an environment resembling a user
# machine: no build environment variables, no SDKROOT, a fresh HOME, and
# the dependency prefix hidden.
native_comp_home=$(mktemp -d)
hidden_deps=""
if [[ -n "${DEPS_PREFIX:-}" && -d "${DEPS_PREFIX}" ]]; then
  hidden_deps="${DEPS_PREFIX}.verify-hidden"
  mv "${DEPS_PREFIX}" "${hidden_deps}"
fi
restore_deps() {
  if [[ -n "${hidden_deps}" && -d "${hidden_deps}" && ! -d "${DEPS_PREFIX}" ]]; then
    mv "${hidden_deps}" "${DEPS_PREFIX}"
  fi
}
trap restore_deps EXIT

env -u CPPFLAGS -u LDFLAGS -u LIBS -u LIBRARY_PATH -u PKG_CONFIG_PATH \
  -u SDKROOT \
  HOME="${native_comp_home}" \
  PATH='/usr/bin:/bin:/usr/sbin:/sbin' \
  "${app}/Contents/MacOS/Emacs" --batch --eval \
  "(progn
     (require 'comp)
     (unless (native-comp-available-p)
       (error \"native compilation is unavailable\"))
     (let* ((source (make-temp-file \"native-comp-smoke\" nil \".el\"
                                    \"(defun native-comp-smoke () 42)\\n\"))
            (eln (native-compile source)))
       (delete-file source)
       (unless (and eln (file-exists-p eln))
         (error \"native compilation produced no .eln file\"))
       (load eln nil nil t)
       (unless (= (native-comp-smoke) 42)
         (error \"native-compiled function returned the wrong value\")))
     (unless (comp-trampoline-compile 'identity)
       (error \"trampoline compilation failed\")))"

compiled_eln=$(find "${native_comp_home}" -name 'native-comp-smoke*.eln' -type f -print -quit)
test -f "${compiled_eln}"
non_system_eln_libraries=$(otool -L "${compiled_eln}" \
  | tail -n +2 | awk -v id="$(basename "${compiled_eln}")" '$1 != id { print $1 }' \
  | grep -Ev '^(/System/Library/|/usr/lib/)' || true)
if [[ -n "${non_system_eln_libraries}" ]]; then
  echo "Unexpected non-system dynamic libraries in generated .eln:" >&2
  echo "${non_system_eln_libraries}" >&2
  exit 1
fi
rm -rf "${native_comp_home}"
restore_deps
trap - EXIT
