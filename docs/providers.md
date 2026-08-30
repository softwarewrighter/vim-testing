# Backend setup recipes

Every local server below is reached through vimgem's **`openai`
provider**. Switching backend is a base‑URL change and nothing else:

```vim
:AIProvider openai
:AIUrl http://localhost:11434
```

For which of these to actually use on this Mac, and why, see
`mac-analysis.md`. This file is the how.

`just status` shows what is reachable right now, local and cloud.

---

## ollama

Multi‑model, runs as a daemon, easiest to live with.

```sh
brew install ollama
ollama serve &                 # or: just up-ollama
ollama pull qwen2.5-coder:7b
```

```vim
:AIProvider openai
:AIUrl http://localhost:11434
:AIModel qwen2.5-coder:7b
```

* OpenAI‑compatible surface is at `/v1` — vimgem adds that itself, so
  the base URL must **not** include it.
* **`g:openai_model` is required.** Ollama is multi‑model and has no
  default.
* `:AIModels` lists everything pulled; `:AIModel` switches with no
  restart. This is the only backend where in‑editor model switching
  works end to end.
* Models unload after 5 minutes idle, and the next request pays the load
  again (1.4 s for a 7B, 16 s for a 31B here). Raise it:

  ```sh
  OLLAMA_KEEP_ALIVE=2h ollama serve
  ```

* `curl localhost:11434/api/ps` shows what is currently resident.

---

## llama.cpp (`llama-server`)

One model per process, full control over server flags.

```sh
brew install llama.cpp
llama-server -m ~/tmp-hf/model.gguf --host 127.0.0.1 --port 8080 -c 8192 -ngl 99
# or: just up-llamacpp ~/tmp-hf/model.gguf
```

```vim
:AIProvider openai
:AIUrl http://127.0.0.1:8080
:AISet openai_model
```

* `-ngl 99` offloads all layers to the Metal GPU. On Apple Silicon this
  is the difference between usable and not.
* `-c` sets context size. Raise it before sending whole files with
  `:AIReviewFile` or `{=<file=}`.
* **Leave `g:openai_model` empty.** With one model loaded, omitting the
  field is correct, and it is vimgem's default.
* `:AIModels` works and reports the model by **full filesystem path**.
* ⚠️ **`llama-server` answers `GET /v1/models` before the weights are
  loaded.** A models‑endpoint poll reports "up" seconds early and the
  first real requests fail. Wait for an actual completion —
  `scripts/lib.sh` `wait_for_ready` and `just up-llamacpp` do this.

---

## vLLM

High‑throughput serving for NVIDIA hardware.

```sh
uv pip install vllm
vllm serve <model> --port 8000
```

```vim
:AIProvider openai
:AIUrl http://127.0.0.1:8000
:AIModel <the exact served model name>
```

* Multi‑model in the sense that the served name must match exactly, so
  **`g:openai_model` is required.**
* **Not worth using on this Mac.** vLLM's advantages are CUDA kernels and
  paged attention; there is no Metal backend, so Apple Silicon gets a
  CPU‑only build that is slower than llama.cpp with Metal at every size.
  Test it on the Linux box.

---

## FreeToken

[FreeToken](https://www.freetoken.wiki/) (FlashML / UC Berkeley) is an
edge‑native MoE serving engine: it keeps most weights in system RAM and
pulls only the experts a token needs onto the GPU, and it exposes
OpenAI‑ and Anthropic‑compatible APIs. That means it should drop into
vimgem's `openai` provider with only a base‑URL change.

**Not installed here, and not verified.** The published material
describes consumer **NVIDIA** GPUs; I found no confirmation of Apple
Silicon support. Treat this section as a plan, not a recipe.

It is aimed squarely at large sparse MoE models — including
`Qwen3.6-35B-A3B-UD-Q4_K_M.gguf`, already in `~/tmp-hf`. Best tried on
the Linux box.

Once running, it should be:

```vim
:AIProvider openai
:AIUrl http://127.0.0.1:<port>
:AIModel <served name>
```

and `just test-llamacpp --url …` (the generic live‑server suite) will
qualify it.

---

## Anything else OpenAI‑compatible

LM Studio, mlx_lm.server, text-generation-webui, LiteLLM, OpenRouter,
api.openai.com itself — all the same shape. Requirements:

* `POST {base_url}/v1/chat/completions`
* `GET {base_url}/v1/models` for `:AIModels` (optional; only that command
  needs it)
* base URL with **no trailing slash and no `/v1` suffix**
* `g:openai_api_key` if the server wants auth; it is sent as
  `Authorization: Bearer …` and omitted entirely when empty

Quick compatibility check before involving Vim:

```sh
curl -s $URL/v1/models | jq '.data[].id'
curl -s $URL/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"say OK"}]}' \
  | jq -r '.choices[0].message.content'
```

If both work, vimgem will work.

---

## A remote server on the LAN

Nothing special — point the URL at the other host, and make sure the
server binds `0.0.0.0` rather than `127.0.0.1`:

```sh
llama-server -m model.gguf --host 0.0.0.0 --port 8080
ollama:  OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

```vim
:AIUrl http://large12.local:8080
```

Qualify it with `just test-remote http://large12.local:8080`.

> **`large12.local` (192.168.1.177) runs ollama on the standard port
> 11434 with 21 models**, and the full live suite passes against it
> (`just test-remote`). Note the standard ollama port: an earlier probe
> here defaulted to 8080 and wrongly reported the host as down.

**Traffic is plain HTTP with no authentication.** Fine on a trusted LAN;
put it behind a tunnel or a reverse proxy with TLS otherwise.

---

## Cloud providers

These are *not* the `openai` provider — they are separate implementations
with their own model names, API‑version settings, and env‑var keys.

| | gemini | claude |
|---|---|---|
| Key | `$GOOGLE_API_KEY` | `$ANTHROPIC_API_KEY` |
| Default model | `gemini-3.5-flash-lite` | `claude-sonnet-4-6` |
| Version setting | `g:gemini_api_version` (`v1`) | `g:claude_api_version` (`2023-06-01`) |
| `:AIModels` | live query, filtered to `generateContent` | curated hardcoded list — no public endpoint |

```vim
:AIProvider gemini
:AIProvider claude
```

Keys are read from the process environment **at Vim startup**. Export
them in your shell rc and restart Vim, or set them for the session with
`:AISet gemini_api_key …`.
