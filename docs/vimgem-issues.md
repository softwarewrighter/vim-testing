# vimgem issues discovered by this test suite

These four defects were reproduced against vimgem 0.1.260827. The
plugin is distributed separately and is not modified by this repository.

There are currently no upstream issue URLs, issue numbers, acknowledgements,
or fixed builds recorded here. Until those references are added, the status of
each item is **reproduced locally; prepared for upstream reporting**.

Executable reproductions live in `vim/t/090-known-issues.vim` and
`scripts/interactive.exp`. Run them with:

```sh
just test-one 090-known-issues
just test-interactive
```

## Issue 1 — chat session IDs collide, silently destroying history

**Severity: high — silent data loss.**

`autoload/ai/buffer.vim` `CreateChat()` creates an ID with only one-second
resolution:

```vim
var chat_id = strftime('%Y%m%d-%H%M%S')
```

It performs no uniqueness check and then calls `SaveHistory(chat_id, [])`.
Opening two chats within the same second gives both chats the same ID. The
second chat resets the first session's JSON history to an empty list. Its
Markdown transcript still contains the earlier turn, so the loss of model
context is not apparent, and both buffers subsequently write to the same
files.

The automated reproduction has two TODO assertions: one for unique IDs and
one for preserving the first chat's history.

**Suggested fix:** If the target path already exists, append `-1`, `-2`, and
so on, or use an ID with sufficient sub-second resolution.

**Status:** Reproduced against 0.1.260827; no upstream issue or fixed build is
recorded.

## Issue 2 — `:AIQuery` truncation warning is transient

**Severity: medium — a cut-off answer can look complete.**

`autoload/ai/core.vim` announces a truncated `:AIQuery` response with a bare
`:echo`. The warning is absent from the output buffer and disappears on the
next keystroke. The write-target path already handles this more safely by
placing a warning in its output.

Silent Ex mode also cannot observe the transient message, so the automated
reproduction remains a TODO assertion.

**Suggested fix:** Add the truncation warning to the `:AIQuery` output buffer,
as the write-target path already does.

**Status:** Reproduced against 0.1.260827; no upstream issue or fixed build is
recorded.

## Issue 3 — hit-enter prompts interrupt normal use

**Severity: low — repeated interactive friction.**

On an 80-by-24 terminal, messages from `:AIChat`, `:AIChatSend`, and `:AIInfo`
can overflow Vim's command line. Vim then displays `Press ENTER or type
command to continue`, waits for input, and temporarily hides the buffer that
was just opened.

This behavior requires a real pseudo-terminal and is covered by the TODO in
`scripts/interactive.exp`, not by the headless batch suite.

**Suggested fix:** Shorten or silence the messages, or use a non-blocking,
recallable message mechanism.

**Status:** Reproduced against 0.1.260827; no upstream issue or fixed build is
recorded.

## Issue 4 — a configuration value cannot be cleared at runtime

**Severity: low — troublesome when switching server types.**

`:AISet <key>` without a value reports the current value instead of clearing
it. After `:AIModel some-model-name`, running `:AISet openai_model` therefore
leaves the model unchanged.

An empty `g:openai_model` is meaningful: vimgem then omits the `model` field
from requests, which is the appropriate shape for some single-model servers.
There is no documented runtime path back to that state without restarting
Vim. This issue is less relevant when using only Ollama, because Ollama
requires a model name, but it remains a defect in vimgem's configuration
interface.

**Suggested fix:** Support an explicit empty value or add an `:AIUnset`
command.

**Status:** Reproduced against 0.1.260827; no upstream issue or fixed build is
recorded.

## Tracking checklist

When any issue is submitted upstream, add its URL and submission date to its
status above. When a new vimgem build arrives, run both reproduction commands
before marking an issue fixed. A formerly failing TODO that begins passing is
evidence to inspect; remove the TODO marker only after confirming the behavior
and recording the fixed version here.
