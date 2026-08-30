# Installing and configuring vimgem

`doc/vimgem.txt` is a good reference manual, but it has no installation
section — it starts from "Requirements" and jumps to using the plugin.
This fills that gap and covers first‑run configuration for each provider.

> **Where this file lives, and why.** `~/.vim` is a byte‑identical unpack
> of `vimgem_0.1.260827_nopack.tgz` — verified, not assumed. Anything
> written into `plugin/`, `autoload/`, or `doc/` will be **destroyed by
> the next release**. So this document lives in the separate
> `vim-testing` repo, which the tarball cannot touch. If you want it in
> the manual, send it upstream to the author as a patch to
> `doc/vimgem.txt`.

---

## 1. Requirements

| | |
|---|---|
| **Vim 9.1 or newer** | The plugin uses vim9script `class` and `abstract class`. It checks `has('patch-9.1.0000')` and refuses to load below that. |
| **`curl` on `$PATH`** | Every API call shells out to `curl`. The plugin `:echoerr`s and stops without it. |
| **One configured provider** | An API key for gemini/claude, or a reachable base URL for anything OpenAI‑compatible. |

Check before installing:

```sh
vim --version | head -1     # want 9.1 or higher
command -v curl
```

macOS ships Vim 9.1 as of recent releases; `brew install vim` if yours is
older. Note that **`/usr/bin/vi` is not the same binary** — check the one
your `$PATH` actually resolves.

---

## 2. Install

The tarball has **no top‑level directory** — its paths start at
`plugin/`, `autoload/`, and `doc/`. It is meant to be extracted from
*inside* a Vim runtime directory, and it will overwrite same‑named files
without asking.

### Standard install (into `~/.vim`)

```sh
# 1. back up anything you have there already
[ -d ~/.vim ] && tar czf ~/vim-backup-$(date +%Y%m%d).tgz -C ~ .vim

# 2. look before you leap -- confirm the paths are what you expect
tar tzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz

# 3. unpack
mkdir -p ~/.vim
tar xzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz -C ~/.vim

# 4. build the help tags so :help vimgem works
vim -es -c 'helptags ~/.vim/doc' -c 'qa!' </dev/null

# 5. the runtime dirs the plugin expects but does NOT create
mkdir -p ~/.vimgem/log        # debug logging is silently dead without this
mkdir -p ~/.vimgem/ai-chat    # chat home; this one IS auto-created
```

Step 5 matters: `~/.vimgem/log/` is **not** created automatically, and
without it `:DBGSet` produces no output at all and gives no hint why.

### Side‑by‑side install (to try a version without disturbing `~/.vim`)

```sh
mkdir -p ~/vimgem-test
tar xzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz -C ~/vimgem-test
vim --clean --cmd 'set runtimepath^=~/vimgem-test' --cmd 'syntax on'
```

`install.sh` automates exactly this:
`./install.sh subject/vimgem_0.1.260827_nopack.tgz` unpacks to
`subject/vimfiles-<version>/` and runs the full suite against that copy,
leaving `~/.vim` untouched. `just test-tgz <file>` does the same with a
throwaway temp dir.

### Verify

```sh
vim -es --not-a-term -c 'AIInfo' -c 'w! /dev/stdout' -c 'qa!' </dev/null | head -20
```

or, from the testing directory, `just check` followed by
`just test-offline`.

Inside Vim, `:AIInfo` should report a version — if it says `NULL`, the
package was built without its version stamp.

### Uninstall

```sh
rm -rf ~/.vim/plugin/ai.vim ~/.vim/autoload/ai ~/.vim/doc/vimgem.txt
rm -rf ~/.vimgem       # also deletes your saved chats -- check first
```

---

## 3. First‑run configuration

vimgem works with no `.vimrc` at all: it defaults to the `gemini`
provider and reads `$GOOGLE_API_KEY` from the environment. Everything
below is optional and can also be changed at runtime.

Two ways to configure, and they behave differently:

* **`.vimrc` (`let g:…`)** — read once at startup. Normal `:let`
  semantics, so **strings are quoted**.
* **`:AISet key value`** — runtime, this session only. Values are
  **literal text and are NOT evaluated**, so **do not quote them**:

  ```vim
  :AISet gemini_api_version v1beta      " right
  :AISet gemini_api_version "v1beta"    " WRONG -- sets 8 chars, quotes included
  ```

  This is the single most common configuration mistake, and it fails at
  request time with a confusing API error rather than at set time.

### Local model (recommended starting point)

No API key, no account, nothing leaves the machine. Every local
backend — ollama, llama.cpp, vLLM, LM Studio, mlx_lm — is the **same
`openai` provider**; only the URL changes.

```vim
" ~/.vimrc
let g:ai_provider     = "openai"
let g:openai_base_url = "http://localhost:11434"   " no trailing slash, no /v1
let g:openai_model    = "qwen2.5-coder:7b"
```

Or at runtime:

```vim
:AIProvider openai
:AIUrl http://localhost:11434
:AIModel qwen2.5-coder:7b
```

`g:openai_model` may be left empty for a **single‑model** server such as
`llama-server` — vimgem then omits the `model` field entirely, which is
what those servers expect. **Multi‑model servers (ollama, vLLM,
api.openai.com) require it.** See `providers.md` for per‑backend setup
and `mac-analysis.md` for which model to choose.

### Gemini

```sh
export GOOGLE_API_KEY="…"      # in your shell rc, then restart Vim
```

```vim
let g:ai_provider = "gemini"           " the default; may be omitted
let g:gemini_model = "gemini-3.5-flash-lite"
```

`$VAR` is read from the process environment **at Vim startup**, so
exporting it in `.vimrc` does not work — export it in the shell and
restart Vim, or use `:AISet gemini_api_key …` for the current session.

### Claude

```sh
export ANTHROPIC_API_KEY="sk-ant-…"
```

```vim
let g:ai_provider  = "claude"
let g:claude_model = "claude-sonnet-4-6"
```

Claude has no public models endpoint, so `:AIModels` returns a curated
hardcoded list rather than a live query.

---

## 4. Settings reference

Plugin‑wide:

| Setting | Default | Purpose |
|---|---|---|
| `g:ai_provider` | `"gemini"` | `gemini`, `claude`, or `openai` |
| `g:show_prompt` | `1` | echo the prompt and a provider/model header above responses |
| `g:vimgem_chat_home` | `~/.vimgem/ai-chat` | chat storage; falls back to `$VIMGEM_CHAT_HOME` |
| `g:ai_chat_autosave` | `1` | write the `.md` transcript every turn |
| `g:ai_chat_html_autosave` | `1` | render the `.html` sidecar every turn |
| `g:always_review_received_files` | `1` | **the guard against clobbering files on disk** — `1` opens received files in a review tab, `0` writes them straight out |
| `g:ai_curl_trace_level` | `9` | debug level at which the redacted curl command is logged |
| `g:ai_no_mappings` | unset | set to `1` to suppress all default `\`‑mappings |

Per provider: `g:gemini_model`, `g:gemini_api_version`,
`g:claude_model`, `g:claude_api_version`, `g:openai_base_url`,
`g:openai_model`, `g:openai_api_key`.

`:AISet` with no arguments lists every settable key; the key argument
tab‑completes.

---

## 5. Default mappings

Suppress all of them with `let g:ai_no_mappings = 1`. Each is defined
only if you have not already mapped that key, so your own mappings always
win.

| Key | Command | | Key | Command |
|---|---|---|---|---|
| `\c` | `:AIChat` | | `\i` | `:AIInfo` |
| `\s` | `:AIChatSend` | | `\m` | `:AIModel` |
| `\r` | `:AIChatResume` | | `\l` | `:AIModels` |
| `\h` | `:AIChatHistory` | | `\p` | `:AIProvider ` |
| `\d` | `:AIChatDelete` | | `\w` | `:AIReviewReceived ` |
| `\v` | `:AIChatDisplay` | | `\g` | `:DBGShowLog` |
| | | | `\j` | `:DBGShowJson` |

---

## 6. Troubleshooting

**"vimgem requires Vim 9.1 or higher"** — check `vim --version | head -1`
and confirm `$PATH` resolves to the Vim you think it does.

**"vim-ai-plugin requires curl to be installed"** — nothing else loads
until `curl` is on `$PATH`.

**`:AIQuery` does nothing / `:help vimgem` not found** — `~/.vim` is not
in `'runtimepath'`, or `helptags` was never run. Check with
`:echo &runtimepath` and `:echo globpath(&rtp, 'plugin/ai.vim')`.

**"GOOGLE_API_KEY environment variable not set"** — export it in your
shell, not in `.vimrc`, and restart Vim.

**Debug logging produces nothing** — `~/.vimgem/log/` must exist; the
plugin does not create it. Then `:DBGSet 1`.

**Any API error** — `:DBGSet 9`, retry, then `:DBGShowLog`. The exact
curl command (with the key redacted) and the raw server response are
there. This is the fastest route to a diagnosis by a wide margin.

**A local server "is running" but requests fail** — `llama-server`
answers `/v1/models` *before* its weights finish loading. Wait for a real
completion to succeed, or use `just up-llamacpp`, which probes correctly.

**Chats disappear or lose context** — see Issue 1 in `test-plan.md`:
opening two chats within the same second makes them collide and wipes the
first one's history. Pause a second between `\c` presses until that is
fixed upstream.
