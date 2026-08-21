#!/bin/bash
# Clone, patch, configure, and build Emacs against the static dependencies in
# DEPS_PREFIX, then assemble Emacs.app and Emacs Client.app and pack the
# release tarball at ${BUILD_DIR}/${TARBALL}.

set -euo pipefail

: "${DEPS_PREFIX:?DEPS_PREFIX must be set}"
: "${EMACS_BRANCH:?EMACS_BRANCH must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${TARBALL:?TARBALL must be set}"
EXTRA_CONFIGURE=${EXTRA_CONFIGURE:-}

script_dir=$(cd "$(dirname "$0")" && pwd)

export PATH="${DEPS_PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${DEPS_PREFIX}/lib/pkgconfig:${DEPS_PREFIX}/share/pkgconfig"
export CPPFLAGS="-I${DEPS_PREFIX}/include"
export LDFLAGS="-L${DEPS_PREFIX}/lib"

git clone --depth 1 -b "${EMACS_BRANCH}" https://github.com/emacs-mirror/emacs.git "${BUILD_DIR}"
cd "${BUILD_DIR}" && sed -i '' '/darwin/ s/lncurses/lncursesw/g' configure.ac
curl -fL -O https://github.com/d12frosted/homebrew-emacs-plus/raw/refs/heads/master/patches/emacs-31/system-appearance.patch --retry 3
curl -fL -O https://github.com/d12frosted/homebrew-emacs-plus/raw/refs/heads/master/patches/emacs-31/round-undecorated-frame.patch --retry 3
patch -f -V none -p1 < system-appearance.patch
patch -f -V none -p1 < round-undecorated-frame.patch
./autogen.sh && ./configure PKG_CONFIG="${DEPS_PREFIX}/bin/pkgconf --static" \
                            --disable-build-details          \
                            --disable-gc-mark-trace          \
                            --without-all                    \
                            --with-compress-install          \
                            --with-file-notification=kqueue  \
                            --with-libgmp                    \
                            --with-gnutls                    \
                            --with-modules                   \
                            --with-native-image-api          \
                            --with-ns                        \
                            --with-small-ja-dic              \
                            --with-threads                   \
                            --with-toolkit-scroll-bars       \
                            --with-tree-sitter               \
                            --with-xwidgets                  \
                            --with-xml2                      \
                            --with-zlib                      \
                            --with-sqlite3                   \
                            --prefix="${PWD}/../emacs-install" \
                            ${EXTRA_CONFIGURE}
make -j4 && make install
ditto nextstep/Emacs.app Emacs.app
# Add command-line helpers used by the packaged apps.
cat > Emacs.app/Contents/MacOS/bin/emacs << 'EOF'
#!/bin/bash
exec /Applications/Emacs.app/Contents/MacOS/Emacs "$@"
EOF
chmod +x Emacs.app/Contents/MacOS/bin/emacs
# Replace app icon
curl -fLO https://github.com/jimeh/emacs-liquid-glass-icons/raw/refs/heads/main/Resources/EmacsLG3-Default.icns --retry 3
mv EmacsLG3-Default.icns Emacs.app/Contents/Resources/Emacs.icns
curl -fLO https://github.com/jimeh/emacs-liquid-glass-icons/raw/refs/heads/main/Resources/Assets.car --retry 3
mv Assets.car Emacs.app/Contents/Resources/Assets.car
plutil -replace CFBundleIconName -string EmacsLG3 Emacs.app/Contents/Info.plist
touch Emacs.app
ARTIFACT_VERSION=$(Emacs.app/Contents/MacOS/Emacs --version | sed -nE 's/^GNU Emacs ([0-9.]+).*/\1/p')
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "ARTIFACT_VERSION=${ARTIFACT_VERSION}" >> "$GITHUB_ENV"
fi
bash "${script_dir}/create-emacs-client-app.sh" \
  --emacs-app Emacs.app \
  --client-app "Emacs Client.app" \
  --version "${ARTIFACT_VERSION}"
codesign --force --deep -s - Emacs.app
codesign --force --deep -s - "Emacs Client.app"
tar -Jcf "${TARBALL}" Emacs.app "Emacs Client.app"
