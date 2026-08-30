# vimgem test plan

How this plugin gets tested, what each layer is for, and what testing has
already turned up.

Everything described here is implemented and running. `just test` is
green today: **89 assertions passing, 3 marked TODO** against two real
defects (§6). `just test-ollama` is green against a live
`qwen2.5-coder:7b` (31 assertions), and `just test-tgz` qualifies a
tarball in a sandbox without touching `~/.vim`.

---

## 1. Your questions, answered first

**Does Vim have a batch mode like Emacs?** Yes, and it is better than the
situation warrants. `vim -es --not-a-term -S script.vim` runs a Vim9
script headlessly with the plugin fully loaded, and `writefile()` gets
results out. A complete `:AIChat` → `:AIChatSend` → resume → delete cycle
against a live model runs in about a third of a second, with no terminal
involved. **This is the primary test mechanism, and it covers far more
than expected: commands, config, provider switching, model listing, chat
lifecycle, reference directives, and every error path.**

Three things bite, and all three are handled in `scripts/lib.sh`:

* **stdin must be `/dev/null`.** In `-es` mode any prompt — an unhandled
  error, a hit‑enter, a pager stop — reads stdin and blocks *forever*
  with no output. This cost me a two‑minute hang before the harness
  existed.
* **macOS has no `timeout(1)`.** `with_timeout` in `lib.sh` is a portable
  replacement, so nothing needs coreutils.
* **`-es` is silent mode: `:echo` output is suppressed** and never
  reaches `:redir`. Anything the plugin reports via `:echo` is invisible
  to batch testing — which is itself a finding (§6, Issue 2).

**Does `expect` work well for scripting interactive Vim tests?** It is
installed at `/usr/bin/expect` and it works — but it is the wrong default
and the right specialist. Batch mode is faster, more precise, and easier
to assert on. `expect` earns its keep for the ~10% that batch mode
*structurally* cannot reach:

* **key mappings as keystrokes.** `:AIChat` working tells you nothing
  about whether `\c` fires.
* **anything that prompts**, since a prompt is invisible headlessly.
* **`:echo` / `echohl` output**, suppressed by `-es`.
* **screen rendering**: `aimd` highlighting, splits, pager behaviour.

`scripts/interactive.exp` is that layer — four assertions, and it found a
real problem on its first run (§6, Issue 3).

**Is VHS an alternative to `expect`?** For *driving* a terminal, yes —
VHS has its own script language (`Type`, `Enter`, `Sleep`, `Screenshot`)
and drives a real PTY through `ttyd`, so for recording you do not need
`expect` at all. For *testing*, no: VHS has no assertions and no exit
status tied to what happened, and its `Sleep` timings make it flaky as a
gate. **Use VHS for demos only; use `expect` when you need a real
terminal and a pass/fail.** They overlap in mechanism, not in purpose.

**Can VHS record install / configure / list models / switch providers /
prompts and responses?** Yes — five tapes are written, one per scenario
(§5). They are **not yet validated**: `vhs` and `ttyd` are not installed
here. `just install-tools` then `just videos`.

---

## 2. The four layers

| Layer | Runs | Speed | Covers | Command |
|---|---|---|---|---|
| **1. Offline** | headless Vim, no server | <1 s | plugin loads, commands defined, config round‑trips | `just test-offline` |
| **2. Mock** | headless Vim + mock HTTP server | ~10 s | all behaviour, incl. every error path | `just test` |
| **3. Live** | headless Vim + real model | 1–5 min | real‑server compatibility | `just test-ollama` |
| **4. Interactive** | `expect` + real PTY | ~20 s | mappings, prompts, rendering | `just test-interactive` |

**Tier selection is automatic.** The mock-backed files drive the server
with `!echo` / `!count` / `!dump` directives that no real model honours,
so running them live would assert on gibberish. `run-tests.sh` therefore
gives a live backend only the server-independent files (`010`, `020`,
`040`) plus `100-live-smoke`, and gives the mock everything else. Live
assertions are loose about *content* and strict about *mechanics*.

The split exists because **the mock owns correctness and the live
backends own compatibility.** Live models are slow, non‑deterministic,
and physically cannot produce an HTTP 500, malformed JSON, or a
`finish_reason: "length"` on demand. The mock produces all of them in
milliseconds. Conversely the mock cannot tell you that `llama-server`
reports models by full filesystem path. Neither layer substitutes for
the other.

### The mock server

`scripts/mock_openai.py` — dependency‑free, implements `GET /v1/models`
and `POST /v1/chat/completions`. The reply is chosen by a directive in
the prompt:

| Directive | Effect |
|---|---|
| `!echo <text>` | reply verbatim — deterministic assertions |
| `!count` | reply `turns=<n>`, the number of messages received |
| `!dump` | reply with every message as `role:text` |
| `!truncate` | `finish_reason: "length"` |
| `!status <code>` | that HTTP status plus an error body |
| `!apierror <msg>` | HTTP 200 carrying an `error` object |
| `!badjson` | HTTP 200 carrying non‑JSON |
| `!slow <secs>` | sleep, for timeout tests |

`!count` and `!dump` are the important ones: they turn "did the reply
look right" into **"exactly what went over the wire"**. `!count` is how
`050-chat` proves conversation history is genuinely resent rather than
assumed — a stateless implementation would answer `turns=1` where a
correct one answers `turns=3`. Every request is also logged as JSON
lines, so the shell can assert on the payload independently.

---

## 3. What is covered

`vim/t/`, numbered in dependency order:

| File | Asserts |
|---|---|
| `010-load` | commands defined, version stamped, mappings installed |
| `020-config` | `:AIProvider` / `:AISet` / `:AIUrl` / `:AIPrompt` round‑trips, invalid‑provider rejection, `:AIUrl` refusing non‑openai providers |
| `030-query` | `:AIQuery` happy path, `show_prompt` on/off, truncation, HTTP error, API‑error object, unparseable JSON |
| `040-models` | `:AIModels` listing, switch‑by‑cursor, switch‑by‑name, cross‑provider warning is advisory not blocking |
| `050-chat` | session files created, **history genuinely resent**, mid‑chat `:AIModel` recorded per turn, `:AIChatClear` empties JSON but not transcript, `:AIChatSend` outside a chat errors |
| `060-history` | `:AIChatHistory` listing, `:AIChatResume` by cursor preserving history, `:AIChatDelete` removing both files and refreshing in place |
| `070-references` | `{='a=}`, `{=1,3<'a>=}` ranges, `{=<file=}` whole‑file with `[ID:]` markers, **failed reference aborts the whole send**, `{=>name=}` diverts the reply and is stripped before sending |
| `080-wire` | `model` omitted when unset vs. sent when set; API key becomes a bearer header |
| `090-known-issues` | executable reproductions of §6 |
| `080-wire` + `scripts/assert-wire.sh` | the Vim half asserts the request *succeeds*; the shell half reads the mock's request log and asserts its *shape* — model field omitted vs. named, never an empty string, bearer header present only when a key is set, chat turns really carrying >1 message, only valid roles |
| `100-live-smoke` | **live tier only** — real server lists models, `:AIQuery` returns a non-empty non-error reply, chat files created, history grows two entries per turn, model recorded in the transcript. Times every round trip into the TAP diagnostics. |

### Deliberately not covered yet

* **HTML rendering / `:AIChatDisplay`** — opens a browser; assert on the
  generated `.html` instead. Straightforward, not yet written.
* **`md.vim` / `md_syntax.vim` AST and highlighting** — 860 lines with a
  ready‑made oracle in `:DBGShowAST`. The highest‑value gap.
* **gemini and claude providers** — no credentials on this machine. The
  mock is OpenAI‑shaped; a gemini‑shaped and claude‑shaped mock would
  close this without spending tokens.
* **`{=> dir/*=}`** and the `:AIReviewReceived` write‑to‑disk gate — the
  one path that can overwrite real files, so worth testing precisely
  because it is risky.

---

## 4. Conventions

**Isolation.** Every run gets `VIMGEM_CHAT_HOME=out/run-<ts>/chat`.
`vim/testrc.vim` **refuses to start** if that variable is unset or points
at the real `~/.vimgem/ai-chat`, so a test can never eat real chats.

**TAP output.** Each file emits TAP to `out/run-<ts>/<name>.tap`. Chosen
because it is greppable, diffable, and needs no framework.

**`TODO` for known defects.** `H.Todo(cond, name, why)` reports a filed,
still‑unfixed bug without reddening the suite — and if it ever *passes*,
TAP flags it as unexpectedly‑passing and you know the fix landed. This is
how §6 stays visible without blocking.

**Testing a `.tgz` without installing it.** `just test-tgz <file>`
unpacks to a temp dir and runs the whole suite against *that* copy via
`--clean` plus a prepended `runtimepath`, leaving `~/.vim` untouched.
This is the release‑qualification path, and it also A/Bs two versions.

---

## 5. Demo recordings

`videos/`, one tape per scenario you asked for:

| Tape | Shows |
|---|---|
| `01-install.tape` | unpacking the `.tgz`, checking Vim 9.1+ and curl, `helptags`, first `:AIInfo` — into a **throwaway vimdir**, never the real `~/.vim` |
| `02-configure.tape` | providers, `:AIUrl`, `:AISet` and the literal‑value trap |
| `03-models.tape` | `just models`, `:AIModels`, cursor‑to‑select |
| `04-providers.tape` | `just status`, local↔cloud switching |
| `05-chat.tape` | `:AIQuery`, then `\c` / `\s` multi‑turn chat |

`_common.tape` holds shared styling. **All five are recorded and
verified** against real local backends (ollama on :11434 and llama.cpp on
:8080); the `.gif` files sit next to the tapes. `just videos` re-records
them all, `just video 03-models` just one.

Two things learned the hard way, both noted in `_common.tape`:

* **Narration must only ever be typed at a shell prompt**, where a
  leading `#` makes it a comment. Typing it while Vim is running inserts
  it into the buffer and ruins the take — which is exactly what the first
  attempt did.
* **Stacked `-c` flags accumulate messages** until Vim shows a hit-enter
  prompt and the recording ends stuck on it (Issue 3 again). Type the
  commands one at a time inside Vim instead, and follow the noisy ones
  with a bare `Enter`.

`Sleep` durations in `05-chat.tape` assume the ~9 s `qwen2.5-coder:7b`
figures from `mac-analysis.md`; retune for a slower model.

---

## 6. What testing has already found

Four defects are reproduced and maintained in
[`vimgem-issues.md`](vimgem-issues.md), including severity, evidence,
suggested fixes, and upstream status. Reproduce them with
`just test-one 090-known-issues` and `just test-interactive`.

### Issue 1 — chat session IDs collide, silently destroying history

**Severity: high — silent data loss.**

`autoload/ai/buffer.vim` `CreateChat()`:

```vim
var chat_id = strftime('%Y%m%d-%H%M%S')
```

One‑second resolution, no uniqueness check. `CreateChat` then calls
`SaveHistory(chat_id, [])`.

Open two chats within the same second — press `\c` twice, or `:AIChat`
right after closing one — and both get the same ID. The second call
**resets the first session's `.json` history to `[]`**. The `.md`
transcript still shows the earlier turn, so nothing looks wrong; but the
API‑facing context is gone and the model has silently forgotten the
conversation. Both buffers now write to one file.

Verified directly:

```
session1 id=20260830-092850
session2 id=20260830-092850
COLLISION=YES
files: ['chat-20260830-092850.html', '.json', '.md']   # one session, not two
--- json history of session1 after session2 opened: ---
[]
```

It also bit the test suite from the inside: `070-references` opened a
"new" chat that turned out to be the *previous* chat's file, still
holding an unsent line, so the new chat failed on the old chat's text.

*Suggested fix:* if the path exists, append `-1`, `-2`, … or use a
higher‑resolution ID.

### Issue 2 — `:AIQuery` truncation warning is transient and unrecoverable

**Severity: medium — a cut‑off answer is indistinguishable from a
complete one.**

`autoload/ai/core.vim` (~line 157) announces truncation with a bare
`:echo`. It leaves no trace in the output buffer and is gone on the next
keystroke. The write‑target path already does this properly — `core.vim`
~line 284 inlines a `[Warning: Response was truncated before completion…]`
line into the output. `:AIQuery` should do the same.

Secondary effect: because `-es` is silent mode, the warning is also
invisible to automation, which is why `030-query` can only mark it TODO
rather than assert it.

### Issue 3 — hit‑enter prompts interrupt normal use

**Severity: low — friction, found only by `expect`.**

On a real 80×24 terminal, `:AIChat`, `:AIChatSend` and `:AIInfo` each
echo a message long enough to overflow the command line, so Vim draws
`Press ENTER or type command to continue` and waits. Every one costs an
extra keystroke and momentarily hides the buffer just opened.

This is exactly the class of bug batch mode cannot see, and it is the
strongest argument for keeping the `expect` layer.

*Suggested fix:* shorten the messages, use `:echomsg` (recallable via
`:messages` rather than blocking), or `:silent` them and let the buffer
speak for itself.

### Issue 4 — a config value cannot be cleared once set

**Severity: low — but it makes single-model local servers awkward.**

`:AISet <key>` with no value only *reports* the current value; there is
no documented or working way to set a key back to empty at runtime.
Verified: after `:AIModel some-model-name`, running `:AISet openai_model`
leaves it at `some-model-name`.

This matters because `g:openai_model` **being empty is a meaningful
state** — it is what makes vimgem omit the `model` field entirely, which
is the correct request shape for `llama-server`, `mlx_lm.server` and
other single-model backends. So once you have pointed Vim at ollama (which
requires a model name) you cannot get back to the correct shape for
llama.cpp without restarting Vim.

In practice llama.cpp tolerates a stale name, but a stricter server may
try to fetch it — precisely the failure `openai.vim` omits the field to
avoid.

*Suggested fix:* let `:AISet <key> ""` (or an explicit `:AIUnset`) clear a
value.

---

## 7. Open questions

1. **Where is `GOOGLE_API_KEY` set?** It is not in `~/.zshrc`,
   `~/.zshenv`, `~/.zprofile`, or `~/.profile`, and there is **no
   `~/.vimrc` at all** — yet Gemini works for you. Knowing where it comes
   from decides whether the docs should say "export it in your shell rc"
   or something else, and whether CI can ever run the gemini tests.
2. ~~Is `large12.local` up?~~ **Resolved.** It runs ollama on the
   standard port 11434 with 21 models, and the full live suite passes
   against it. My earlier "unreachable" note was wrong: I probed port
   8080 (llama.cpp's) and never tried ollama's. Remaining question is
   what else you want running there — vLLM and FreeToken are both worth
   testing on that box (see `mac-analysis.md` §5).
3. **How is a new `.tgz` delivered?** The current one arrives by hand in
   `~/tools/russt/`, and `~/.vim` is a byte‑identical unpack of it. If
   there is an upstream repo, the docs and these findings belong there
   rather than only here.
4. **`_nopack` in the filename** implies a `pack`‑layout variant exists.
   If so, `01-install.tape` and the install doc should cover both.
5. **Should the suite gate releases?** If yes, `just test` is the hook;
   it needs no network and no credentials.
