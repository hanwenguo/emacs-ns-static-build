[![MacOS Build for GNU Emacs](https://github.com/hanwenguo/emacs-ns-static-build/actions/workflows/build.yml/badge.svg)](https://github.com/hanwenguo/emacs-ns-static-build/actions/workflows/build.yml)

This repository automatically builds GNU Emacs for macOS for my _personal
usage_. Works only on ARM macOS 26. The following branches are built, none of
them with native compilation:

- `master`
- `emacs-31`
- `feature/igc3`

Compared to upstream, these builds have the following differences:

- All external libraries are statically linked (except macOS system libraries),
  thanks to [RadioNoise/ebuild](https://github.com/RadioNoiseE/ebuild)
- Link time optimization enabled
- An `Emacs Client.app` provided, thanks to
  [emacs-plus](https://github.com/d12frosted/homebrew-emacs-plus)
- Patches applied:
  - [`system-appearance`](https://github.com/d12frosted/homebrew-emacs-plus/raw/refs/heads/master/patches/emacs-31/system-appearance.patch)
  - [`round-undecorated-frame`](https://github.com/d12frosted/homebrew-emacs-plus/raw/refs/heads/master/patches/emacs-31/round-undecorated-frame.patch)
  - [`xwidget-pdfkit`](https://github.com/hanwenguo/pdfkit.el) to view PDFs with PDFKit

Install via Homebrew:

```sh
brew install --cask hanwenguo/tap/emacs-ns-static
brew install --cask hanwenguo/tap/emacs-ns-static@master
brew install --cask hanwenguo/tap/emacs-ns-static@igc
```
