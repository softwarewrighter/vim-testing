# Local LLM backends for vimgem on macOS (Apple Silicon)

Measured on this machine, 2026-08-30. A companion `linux-analysis.md`
should be written on the Linux box; the closing section says what to
carry over and what will differ.

| | |
|---|---|
| Host | `max.local`, Apple M1 Max, 32 GPU cores, 64 GB unified memory |
| OS | macOS 26.5 (Darwin 25.5.0), arm64 |
| Vim | 9.1, patches 1‑1752, `/usr/bin/vim` |
| vimgem | 0.1.260827 |

Reproduce any number here with `just bench-ollama`, or
`scripts/bench.sh --url … --model … --unload`.

---

## 1. The thing that decides everything: vimgem blocks

Before any benchmark matters, one implementation detail dominates the
whole question of which model to use.

Every provider calls `system(curl_cmd)` — a synchronous shell‑out
(`autoload/ai/openai.vim` `ExecuteCurl`, and the same in `gemini.vim`
and `claude.vim`). There is no streaming and no job control. **Vim is
frozen — no cursor, no `Ctrl‑C`, no repaint — for the entire duration of
every request.**

So the metric that matters is not tokens/second. It is *total wall time
per request*, because that is exactly how long the editor is dead. A
model that generates at a glorious 34 tok/s but insists on emitting 4000
tokens of reasoning is strictly worse, in an editor, than one that
generates at 12 tok/s and stops after 400.

Everything below is ranked by that.

---

## 2. Measurements

`cold` = first request after the weights are evicted. `warm short` = best
of three `"Reply with exactly: OK"` round trips with the model resident.
`long gen` = one ~400‑word explanation request — the `:AIReviewFile`
shape of workload.

| Backend / model | Size | Cold | Warm short | Long gen | Tokens out | tok/s |
|---|---|---|---|---|---|---|
| ollama `qwen2.5-coder:7b` | 4.7 GB Q4 | 1.4 s | **0.22 s** | **9.2 s** | 437 | 47.3 |
| ollama `gemma4:31b-mlx` | 20 GB | 16.4 s | 2.8 s | 89.4 s | 1125 | 12.6 |
| llama.cpp `ornith-1.0-9b-Q8` | 8.9 GB Q8 | ~5.0 s¹ | 2.7 s | 119.0 s | 4051 | 34.0 |

¹ llama-server process start to weights loaded, from its own log. Not
comparable to ollama's cold number: ollama's daemon is already running
and reloads a model into an existing process.

All cold figures are with the model file already in the OS page cache.
Straight after a reboot, add roughly the time to read the file from
disk.

### Reading the table

**`qwen2.5-coder:7b` is the only one of the three that feels like part of
the editor.** A 0.22 s warm reply is below the threshold where you
notice, and 9 s for a long answer is a pause, not an outage.

**`gemma4:31b-mlx` is a 90‑second freeze on a long answer.** It is the
better model and it is unusable for anything conversational. It earns
its place only for a considered `:AIReviewFile` you are willing to walk
away from.

**`ornith-1.0-9b` is the cautionary tale, and the most interesting
result here.** It is a *reasoning* model. Asked for 400 words it emitted
4051 tokens — the overwhelming majority of them chain‑of‑thought — and
took just under two minutes. Worse, it returns that thinking in a
separate `reasoning_content` field, and vimgem reads only
`choices[0].message.content` (`openai.vim` `ExtractResult`). **You wait
for every one of those tokens and are then shown none of them.** Even
its "Reply with exactly: OK" took 2.7 s, twelve times the 7B's, because
it reasons about the word OK first.

> **Rule of thumb: do not point vimgem at a reasoning model.** Until the
> plugin streams, or learns to surface `reasoning_content`, the thinking
> tokens are pure latency. Prefer instruct/coder tunes, or run the
> reasoning model with thinking disabled if the server supports it.
>
> This is filed as **Issue 5** in `test-plan.md`: it is not only wasted
> latency. When such a model puts little or nothing in `content`, vimgem
> shows a blank buffer or reports "empty or malformed response" — an
> error the server did not cause.

---

## 3. Backend comparison

### ollama — the default recommendation

Already running as a daemon on this machine at `http://localhost:11434`,
with an OpenAI‑compatible surface at `/v1`.

* **The "too much start latency?" worry does not hold.** There is no
  daemon start cost, because it is already up. What looked like start
  latency is model *load* time: 1.4 s for the 7B, 16.4 s for the 31B,
  paid once and then not again while the model stays resident.
* Models stay loaded for 5 minutes by default. Raise it —
  `OLLAMA_KEEP_ALIVE=2h ollama serve`, or per request — and the cold hit
  effectively disappears for a day's work.
* Multi‑model in one process. `:AIModels` lists all three; `:AIModel`
  switches with no server restart. This is the only backend here where
  switching models from inside Vim actually works end to end.
* **`g:openai_model` must be set** — ollama needs to know which model you
  mean.

**Use it as the daily driver.**

### llama.cpp (`llama-server`) — control, one model at a time

* One model per process. Switching models means stopping and starting a
  server, so `:AIModel` cannot meaningfully switch anything.
* Gives you what ollama hides: `-c` context size, `-ngl` GPU layers,
  sampling flags, exact quantisation of your own `.gguf` files.
* `:AIModels` works, and lists the model by its **full filesystem path**
  (`/Users/mike/tmp-hf/ornith-1.0-9b-Q8_0.gguf`).
* `g:openai_model` can be left empty — with a single loaded model,
  omitting the field is correct and is what vimgem does by default.
* **Gotcha, and it cost me a bad benchmark run:** `llama-server` starts
  answering `GET /v1/models` as soon as its socket opens, *seconds before
  the weights finish loading*. A models‑endpoint poll reports "up" early
  and the first real requests come back as errors. `scripts/lib.sh`
  `wait_for_ready` probes with an actual completion instead; use that.

**Use it when you want a specific `.gguf` or specific server flags.**

### vLLM — not a Mac story

vLLM's throughput advantages come from CUDA kernels and paged attention
on NVIDIA hardware. On Apple Silicon there is no Metal backend; you get
a CPU‑only build, which is slower than llama.cpp with Metal at every
size. **Skip vLLM here. Test it on the Linux box**, where it is the right
tool for serving one model to several clients at once.

### FreeToken — not installed, and probably not a Mac story either

[FreeToken](https://www.freetoken.wiki/) (FlashML / UC Berkeley) is an
edge‑native MoE serving engine that keeps most weights in system RAM and
pulls only the experts a token needs onto the GPU, exposing an
OpenAI‑compatible API — so it would drop straight into vimgem's `openai`
provider with only a base‑URL change. The published material describes
consumer **NVIDIA** GPUs; I found no confirmation of Apple Silicon
support and have not installed it, so this is unverified.

It is worth trying on the Linux box, and it is aimed squarely at the
`Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` MoE already sitting in `~/tmp-hf`.

### Cloud (gemini / claude)

Separate providers, not the `openai` one, each with its own model name
and API‑version setting and an env‑var key. Neither `GOOGLE_API_KEY` nor
`ANTHROPIC_API_KEY` is set in the login shell on this machine, and there
is no `~/.vimrc` — so whatever is making Gemini work today is being
exported interactively. Worth pinning down; see the open questions in
`test-plan.md`.

---

## 4. Recommendations for this Mac

1. **Daily driver: ollama + `qwen2.5-coder:7b`**, with
   `OLLAMA_KEEP_ALIVE` raised.

   ```vim
   " ~/.vimrc
   let g:ai_provider     = "openai"
   let g:openai_base_url = "http://localhost:11434"
   let g:openai_model    = "qwen2.5-coder:7b"
   ```

2. **Heavier review work: `gemma4:31b-mlx`**, switched to per task with
   `:AIModel gemma4:31b-mlx` and switched back after. Expect ~90 s of
   frozen editor per long answer.

3. **Avoid reasoning models** (`ornith-*`, `gpt-oss-*`) until vimgem
   streams or surfaces `reasoning_content`.

4. **Reach for llama.cpp** only when you need a specific `.gguf` or
   server flag. Use `just up-llamacpp <path.gguf>`, which waits for real
   readiness rather than a misleading models‑endpoint probe.

5. **The untested 64 GB question:** the 35B MoE
   (`Qwen3.6-35B-A3B-UD-Q4_K_M.gguf`, 21 GB) is the most interesting
   unmeasured model here — MoE means only ~3B parameters are active per
   token, so it may land near the 7B's speed with far better quality.
   `just up-llamacpp ~/tmp-hf/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` then
   `just bench …` would settle it in about ten minutes.

---

## 5. For the Linux counterpart

Carry over unchanged:

* The blocking‑`curl` constraint. It is in the plugin, not the platform,
  so total wall time is the metric there too.
* The reasoning‑model warning, for the same reason.
* Everything in `test-plan.md`. The batch suite is platform‑independent;
  only `--url` changes.

Expect to differ:

* **vLLM becomes viable and probably wins** for a shared or multi‑client
  server on NVIDIA hardware.
* **FreeToken becomes testable**, and is aimed at exactly the large MoE
  models worth running on a bigger box.
* **llama.cpp uses `-ngl` against CUDA rather than Metal**, and VRAM,
  not unified memory, becomes the binding constraint — a 20 GB model
  that merely runs slowly on a 64 GB Mac may not fit at all on a 24 GB
  card, or may need CPU offload that changes the numbers completely.
* Cold‑start numbers will be dominated by disk speed and PCIe transfer
  rather than by unified‑memory bandwidth.

Run `just bench-ollama` and the same three phases there, and put the
results in the same table shape so the two files can be read
side by side.
