[![Emacs with fluent cursor](https://github.com/hanwenguo/emacs-ns-static-build/actions/workflows/build.yml/badge.svg?branch=fluent-cursor-artifacts)](https://github.com/hanwenguo/emacs-ns-static-build/actions/workflows/build.yml)

This branch builds GNU Emacs with fluent cursor animation for macOS for my
_personal usage_. Builds run on pushes to `fluent-cursor-artifacts` or through
**Actions → Emacs with fluent cursor → Run workflow**, selecting this branch.
Completed runs provide downloadable Actions artifacts containing `Emacs.app`
and `Emacs Client.app` in a `.tar.xz` archive. Works only on ARM macOS 26.
The following branches are built, none of them with native compilation:

- `master`
- `emacs-31`

Compared to upstream, these builds have the following differences:

- All external libraries are statically linked (except macOS system libraries),
  thanks to [RadioNoise/ebuild](https://github.com/RadioNoiseE/ebuild)
- Link time optimization enabled
- An `Emacs Client.app` provided, thanks to
  [emacs-plus](https://github.com/d12frosted/homebrew-emacs-plus)
- Patches applied:
  - [Fluent cursor animation](patches/fluent-cursor.patch), with native box colors and buffer-local controls
  - [`system-appearance`](https://github.com/d12frosted/homebrew-emacs-plus/raw/refs/heads/master/patches/emacs-31/system-appearance.patch)
  - [`round-undecorated-frame`](https://github.com/d12frosted/homebrew-emacs-plus/raw/refs/heads/master/patches/emacs-31/round-undecorated-frame.patch)
  - [`xwidget-pdfkit`](https://github.com/hanwenguo/pdfkit.el) to view PDFs with PDFKit

Download the artifact for your chosen Emacs branch from the completed workflow
run and extract its `.tar.xz` archive. The optional `channels` workflow input
accepts `master` or `emacs-31`, separated by commas; an empty value builds
both. The build uses the upstream revision recorded by the workflow plan.

Enable animation in your Emacs configuration:

```elisp
(setq-default ns-cursor-animation t
              ns-cursor-animation-response 0.125
              ns-cursor-animation-typing-response 0.125)
```

To disable animation in an individual buffer or from a major-mode hook, use
`(setq-local ns-cursor-animation nil)`. The response settings also support local
overrides. Other buffers inherit the global default. The macOS Reduce Motion
setting takes precedence.
