# justfile -- vimgem test and demo tasks
#
#   just              list recipes
#   just check        are the tools I need installed?
#   just test         full suite against the offline mock (fast, default)
#   just test-ollama  same suite against a live local model
#   just status       what backends are reachable right now
#
# Everything here is a thin wrapper over scripts/*.sh; the scripts work
# standalone if you would rather not use just.

set shell := ["bash", "-uc"]

scripts := justfile_directory() / "scripts"
vhs     := justfile_directory() / "vhs"
videos  := justfile_directory() / "videos"
gifs    := justfile_directory() / "gifs"
out     := justfile_directory() / "out"

default:
    @just --list --unsorted

# -------------------------------------------------------------- install --

# Unpack a .tgz to subject/ and run the suite against it (never touches ~/.vim).
install TGZ:
    @./install.sh {{TGZ}}

# Install into a clean ~/.vim (backing yours up), test, then restore.
install-home TGZ:
    @./install.sh {{TGZ}} --mode home

# ---------------------------------------------------------------- setup --

# Report which tools are present and which are only needed for extras.
check:
    @{{scripts}}/check-deps.sh

# Install the optional tooling (vhs needs ttyd + ffmpeg for recording).
install-tools:
    brew install vhs ttyd ffmpeg

# --------------------------------------------------------------- testing --

# Full suite against the offline mock server. No network, no model, ~10s.
test:
    @{{scripts}}/run-tests.sh --backend mock

# Smoke test for a fresh .tgz install: the tests needing no server at all.
test-offline:
    @{{scripts}}/run-tests.sh --offline

# One test file, by name fragment: `just test-one 050-chat`
test-one FILTER:
    @{{scripts}}/run-tests.sh --backend mock {{FILTER}}

# The same suite against a live local model -- proves real-server compatibility.
test-ollama MODEL="":
    @{{scripts}}/run-tests.sh --backend ollama {{ if MODEL != "" { "--model " + MODEL } else { "" } }}

test-llamacpp URL="http://127.0.0.1:8080":
    @{{scripts}}/run-tests.sh --backend llamacpp --url {{URL}}

# Against another machine on the LAN, e.g. `just test-remote http://large12.local:8080`
test-remote URL="http://large12.local:11434":
    @{{scripts}}/run-tests.sh --backend live --url {{URL}}

# Terminal tests headless Vim cannot do: keymaps, hit-enter prompts, rendering.
test-interactive:
    @{{scripts}}/providers.sh up mock >/dev/null 2>&1 || true
    @mkdir -p {{out}}/interactive
    @VIMGEM_CHAT_HOME={{out}}/interactive {{scripts}}/interactive.exp

# Qualify a release: unpack a .tgz to a sandbox and test THAT, not ~/.vim.
test-tgz TGZ:
    #!/usr/bin/env bash
    set -euo pipefail
    sandbox=$(mktemp -d)
    trap 'rm -rf "$sandbox"' EXIT
    tar xzf "{{TGZ}}" -C "$sandbox"
    echo "unpacked {{TGZ}} -> $sandbox"
    {{scripts}}/run-tests.sh --backend mock --sandbox "$sandbox"

# Everything: offline, mock, interactive.
test-all: test test-interactive

# ------------------------------------------------------------- backends --

# What is reachable right now, local and cloud.
status:
    @{{scripts}}/providers.sh status

up-ollama:
    @{{scripts}}/providers.sh up ollama

up-llamacpp MODEL PORT="8080":
    @{{scripts}}/providers.sh up llamacpp {{MODEL}} {{PORT}}

up-mock PORT="9099":
    @{{scripts}}/providers.sh up mock {{PORT}}

down BACKEND:
    @{{scripts}}/providers.sh down {{BACKEND}}

# --------------------------------------------------------------- models --

# Every model on every live backend.
models BACKEND="":
    @{{scripts}}/models.sh list {{BACKEND}}

# The Vim commands to point the editor at a given backend/model.
use BACKEND MODEL="":
    @{{scripts}}/models.sh use {{BACKEND}} {{MODEL}}

# The .vimrc block to make that the default.
vimrc BACKEND MODEL="":
    @{{scripts}}/models.sh vimrc {{BACKEND}} {{MODEL}}

# One prompt at one model, with timing.
try BACKEND MODEL PROMPT:
    @{{scripts}}/models.sh try {{BACKEND}} {{MODEL}} {{PROMPT}}

# The same prompt at every live model, for side-by-side comparison.
compare PROMPT:
    @{{scripts}}/models.sh compare {{PROMPT}}

# ------------------------------------------------------------ benchmark --

# Cold-start, warm-latency and tokens/sec for one model.
bench URL MODEL="" LABEL="":
    @{{scripts}}/bench.sh --url {{URL}} {{ if MODEL != "" { "--model " + MODEL } else { "" } }} {{ if LABEL != "" { "--label " + LABEL } else { "" } }}

# Benchmark every ollama model in turn, into out/bench.tsv.
bench-ollama:
    #!/usr/bin/env bash
    set -euo pipefail
    url=$({{scripts}}/providers.sh url ollama)
    out={{out}}/bench.tsv
    : >"$out"
    first=1
    for m in $(curl -s "$url/v1/models" | jq -r '.data[].id'); do
        echo "benchmarking $m ..." >&2
        if [ "$first" = 1 ]; then
            {{scripts}}/bench.sh --url "$url" --model "$m" --label "ollama/$m" --unload >>"$out"
            first=0
        else
            {{scripts}}/bench.sh --url "$url" --model "$m" --label "ollama/$m" --unload \
                | tail -n +2 >>"$out"
        fi
    done
    column -t -s $'\t' "$out"

# --------------------------------------------------------------- videos --

# Record every tape in vhs/ -> videos/*.webm and gifs/*.gif (dead air trimmed).
videos: (require-vhs)
    @{{scripts}}/render-videos.sh

# Record one tape: `just video 03-models`
video NAME: (require-vhs)
    @{{scripts}}/render-videos.sh {{NAME}}

[private]
require-vhs:
    @command -v vhs >/dev/null || { echo "vhs is not installed -- run: just install-tools"; exit 1; }

# ---------------------------------------------------------------- chores --

clean:
    rm -rf {{out}}/run-* {{out}}/*.log {{out}}/*.pid {{out}}/requests.jsonl

clean-videos:
    rm -f {{videos}}/*.webm {{gifs}}/*.gif {{out}}/raw/*.webm
