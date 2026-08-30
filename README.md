# vim-testing

Test harness, backend tooling, benchmarks and demo recordings for
**vimgem**, a multi-provider AI assistant plugin for Vim by Russ Tremain.

**The plugin itself is not in this repo.** It ships as a `.tgz` from its
author; publishing it is his call. This repo is the testing work that
surrounds it — point it at a build with `./install.sh`.

## Quick start

```sh
cp ~/tools/russt/vimgem_0.1.260827_nopack.tgz subject/
./install.sh subject/vimgem_0.1.260827_nopack.tgz   # unpack + full suite
just check                                          # dependency report
just status                                         # which LLM backends are up
```

`install.sh` defaults to a **sandbox**: the build is unpacked to
`subject/vimfiles-<version>/` and tested with `--clean` plus that
directory prepended to `'runtimepath'`, so `~/.vim` is never touched and
two releases can be A/B'd side by side.

To verify the tarball in its real location instead:

```sh
./install.sh <tgz> --mode home    # moves ~/.vim -> ~/.bak-vim, tests, restores
./install.sh <tgz> --mode home --keep   # ...and leaves the new build installed
```

Home mode refuses to clobber an existing backup, and an `EXIT` trap puts
your `~/.vim` back even if the tests fail or you interrupt it.

## Docs

| | |
|---|---|
| [`docs/test-plan.md`](docs/test-plan.md) | how testing works, what's covered, **and the four defects found so far** |
| [`docs/install-and-configure.md`](docs/install-and-configure.md) | installing from the `.tgz`; configuring each provider |
| [`docs/providers.md`](docs/providers.md) | per-backend setup: ollama, llama.cpp, vLLM, FreeToken, remote, cloud |
| [`docs/mac-analysis.md`](docs/mac-analysis.md) | **benchmarks: which local model to actually use on Apple silicon** |

A `docs/linux-analysis.md` counterpart belongs on the Linux box; the last
section of `mac-analysis.md` says what carries over and what will differ.

## Demos

Five recordings, each in two forms:

* **`videos/*.webm`** — the deliverable. Scrubbable, pausable, and they
  **end** rather than loop. GitHub will not play these inline, so click
  through to view or download one.
* **`gifs/*.gif`** — the same takes, embedded below. These are built
  **without** the GIF loop extension, so each plays through once and
  stops on its last frame. Collapse and re-expand a section to replay it,
  or open the `.webm` if you want to scrub.

Total: about 112 seconds across all five. Dead air is trimmed
automatically — see [`scripts/render-videos.sh`](scripts/render-videos.sh).

<details>
<summary><b>01 · Install</b> — unpacking the <code>.tgz</code>, requirements, <code>helptags</code>, first <code>:AIInfo</code> (35s)</summary>

Installs into a throwaway vimdir, never the viewer's real `~/.vim`.

![Installing vimgem from the distribution tarball](gifs/01-install.gif)

[`videos/01-install.webm`](videos/01-install.webm)
</details>

<details>
<summary><b>02 · Configure</b> — providers, <code>:AIUrl</code>, and the <code>:AISet</code> literal-value trap (12s)</summary>

`gemini`, `claude`, and `openai` — where `openai` means *any*
OpenAI-compatible server, local ones included.

![Configuring vimgem for a local model server](gifs/02-configure.gif)

[`videos/02-configure.webm`](videos/02-configure.webm)
</details>

<details>
<summary><b>03 · Models</b> — <code>just models</code>, <code>:AIModels</code> local and remote, cursor-select (18s)</summary>

Listing models from the shell and from inside Vim, then switching by
putting the cursor on a model line and running `:AIModel`.

![Listing models and switching between them](gifs/03-models.gif)

[`videos/03-models.webm`](videos/03-models.webm)
</details>

<details>
<summary><b>04 · Providers</b> — three backends: local ollama, local llama.cpp, remote ollama (21s)</summary>

The point of this one: every local server is the *same* vimgem provider
(`openai`). Switching backend is a base-URL change and nothing else —
including to another machine on the LAN.

![Switching between local and remote backends](gifs/04-providers.gif)

[`videos/04-providers.webm`](videos/04-providers.webm)
</details>

<details>
<summary><b>05 · Chat</b> — <code>:AIQuery</code>, then <code>\c</code> / <code>\s</code> multi-turn chat (25s)</summary>

A one-shot query, then a persistent multi-turn conversation against a
real local model.

![A one-shot query and a multi-turn chat](gifs/05-chat.gif)

[`videos/05-chat.webm`](videos/05-chat.webm)
</details>

Re-record everything with `just videos`, or one with `just video 03-models`
(needs `just install-tools` first).

## Layout

```
.
├── install.sh          install a .tgz and test it (sandbox or home mode)
├── justfile            all tasks -- run `just` to list them
├── subject/            the .tgz under test (gitignored)
├── docs/               the four documents above
├── scripts/
│   ├── lib.sh              shared helpers: headless vim, timeouts, TAP
│   ├── run-tests.sh        the test runner
│   ├── mock_openai.py      scriptable mock LLM server -- offline, deterministic
│   ├── assert-wire.sh      asserts the SHAPE of what vimgem sent
│   ├── interactive.exp     expect tests for what headless vim can't reach
│   ├── providers.sh        bring backends up/down, report status
│   ├── models.sh           list / switch / try / compare models
│   ├── bench.sh            cold-start, latency and tok/s
│   ├── render-videos.sh    record tapes, trim dead air, emit webm + gif
│   └── check-deps.sh       dependency report
├── vim/
│   ├── testrc.vim          the vimrc used for tests
│   ├── harness.vim         TAP assertions for vim9script
│   └── t/*.vim             the tests
├── vhs/*.tape          demo sources
├── videos/*.webm       the deliverable recordings
├── gifs/*.gif          same takes, non-looping
└── out/                per-run artifacts (gitignored)
```

## Status

`just test` — **89 assertions passing, 3 TODO** against known defects.
`just test-ollama` and `just test-remote` pass against live models.
`just test-interactive` adds 4 more via a real PTY.

Four defects found so far, all with executable reproductions in
`vim/t/090-known-issues.vim` and written up in
[`docs/test-plan.md`](docs/test-plan.md):

1. **Chat session IDs collide within one second, silently wiping the
   older session's history** (data loss).
2. `:AIQuery`'s truncation warning is a transient `:echo` that leaves no
   trace — a cut-off answer looks complete.
3. Hit-enter prompts interrupt `:AIChat`, `:AIChatSend` and `:AIInfo` on
   a real terminal.
4. A config value cannot be cleared once set, which matters because an
   empty `g:openai_model` is the correct shape for single-model servers.

These are for upstream; nothing here patches the plugin.

## Copyright and license

Copyright (c) 2026 Michael A Wright.

This repository — the test harness, backend tooling, benchmarks,
documentation and demo recordings — is released under the
[MIT License](LICENSE).

The vimgem plugin itself is a separate work by Russ Tremain, distributed
independently as a source tarball. It is not included here and is not
covered by this license; see [COPYRIGHT](COPYRIGHT).
