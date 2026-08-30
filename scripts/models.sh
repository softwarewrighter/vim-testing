#!/usr/bin/env bash
# scripts/models.sh
# List, switch, and try models across every backend, without leaving the
# shell -- the loop you want when deciding which local model to point
# Vim at.
#
#   ./models.sh list                       # every model on every live backend
#   ./models.sh list ollama
#   ./models.sh try ollama qwen2.5-coder:7b "explain a vim9 class"
#   ./models.sh use ollama qwen2.5-coder:7b   # emit the :AIxxx lines to paste
#   ./models.sh vimrc ollama qwen2.5-coder:7b # emit the .vimrc block
#   ./models.sh compare "your prompt"      # same prompt to every live model
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

backend_url() { ./providers.sh url "$1"; }

live_backends() {
    for b in ollama llamacpp vllm mock remote; do
        http_up "$(backend_url "$b")/v1/models" && echo "$b"
    done
}

models_of() {
    curl -s -m 5 "$(backend_url "$1")/v1/models" | jq -r '.data[]?.id' 2>/dev/null
}

cmd_list() {
    local backends
    if [ $# -gt 0 ]; then backends="$*"; else backends="$(live_backends)"; fi
    [ -n "$backends" ] || { warn "no backend is reachable -- try: just status"; return 1; }
    for b in $backends; do
        local url; url="$(backend_url "$b")"
        printf '%s%s%s  (%s)\n' "$C_GRN" "$b" "$C_OFF" "$url"
        models_of "$b" | sed 's/^/    /'
        echo
    done
}

# Print exactly what to type in Vim to point it at this model. vimgem
# reaches every local backend through the one `openai` provider, so
# switching backend is a base-URL change and switching model is :AIModel.
cmd_use() {
    local b="${1:?backend}" m="${2:-}"
    cat <<VIM
" paste into Vim, or run each with :
:AIProvider openai
:AIUrl $(backend_url "$b")
${m:+:AIModel $m}
:AIInfo
VIM
}

cmd_vimrc() {
    local b="${1:?backend}" m="${2:-}"
    cat <<VIM
" ~/.vimrc -- default to $b
let g:ai_provider    = "openai"
let g:openai_base_url = "$(backend_url "$b")"
let g:openai_model    = "${m}"
VIM
}

# One prompt, one model, printed with timing -- the fastest way to judge
# whether a model is worth wiring into the editor at all.
cmd_try() {
    local b="${1:?backend}" m="${2:-}" prompt="${3:?prompt}"
    local url; url="$(backend_url "$b")"
    local body
    if [ -n "$m" ] && [ "$m" != "-" ]; then
        body=$(jq -n --arg m "$m" --arg p "$prompt" \
            '{model:$m, messages:[{role:"user",content:$p}]}')
    else
        body=$(jq -n --arg p "$prompt" '{messages:[{role:"user",content:$p}]}')
    fi
    local t0 t1 out
    t0=$(python3 -c 'import time;print(time.time())')
    out=$(curl -s -m 600 "$url/v1/chat/completions" -H 'Content-Type: application/json' -d "$body")
    t1=$(python3 -c 'import time;print(time.time())')
    printf '%s--- %s / %s  (%ss) ---%s\n' "$C_GRN" "$b" "${m:-default}" \
        "$(python3 -c "print(f'{$t1-$t0:.1f}')")" "$C_OFF"
    printf '%s' "$out" | jq -r '.choices[0].message.content // ("ERROR: " + (.error.message // tostring))'
}

cmd_compare() {
    local prompt="${1:?prompt}"
    for b in $(live_backends); do
        [ "$b" = mock ] && continue
        local ms; ms="$(models_of "$b")"
        if [ -z "$ms" ]; then cmd_try "$b" "" "$prompt"; continue; fi
        while read -r m; do
            [ -n "$m" ] && cmd_try "$b" "$m" "$prompt"
        done <<<"$ms"
    done
}

case "${1:-list}" in
    list)    shift; cmd_list "$@" ;;
    use)     shift; cmd_use "$@" ;;
    vimrc)   shift; cmd_vimrc "$@" ;;
    try)     shift; cmd_try "$@" ;;
    compare) shift; cmd_compare "$@" ;;
    *)       sed -n '2,14p' "$0"; exit 1 ;;
esac
