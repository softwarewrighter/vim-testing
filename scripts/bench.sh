#!/usr/bin/env bash
# scripts/bench.sh
# Measure a running OpenAI-compatible server the way vimgem actually uses
# it, and emit one TSV row per measurement.
#
# The numbers that matter for an in-editor assistant are not the ones
# model leaderboards report:
#
#   cold     first request after the model is evicted/unloaded. This is
#            the "I pressed \s and Vim froze" number, and it is the one
#            that decides whether a backend is usable interactively.
#   warm     steady-state request latency with the model resident.
#   tok/s    generation throughput on a long answer -- what a :AIReviewFile
#            on a real file feels like.
#   ttfb     time to first byte; with vimgem this is nearly the whole
#            wait, because the plugin uses a blocking curl and does not
#            stream, so the editor is unresponsive for the full duration.
#
# Usage:
#   ./bench.sh --url http://localhost:11434 --model qwen2.5-coder:7b \
#              --label "ollama/qwen2.5-coder:7b" [--unload]
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

URL=""; MODEL=""; LABEL=""; UNLOAD=0; REPEAT=3
while [ $# -gt 0 ]; do
    case "$1" in
        --url)    URL="$2"; shift 2 ;;
        --model)  MODEL="$2"; shift 2 ;;
        --label)  LABEL="$2"; shift 2 ;;
        --repeat) REPEAT="$2"; shift 2 ;;
        --unload) UNLOAD=1; shift ;;
        *) die "unknown arg: $1" ;;
    esac
done
[ -n "$URL" ] || die "--url is required"
LABEL="${LABEL:-$MODEL}"

payload() {
    local prompt="$1" maxtok="${2:-}"
    if [ -n "$MODEL" ]; then
        jq -n --arg m "$MODEL" --arg p "$prompt" \
            '{model:$m, messages:[{role:"user",content:$p}]}'
    else
        jq -n --arg p "$prompt" '{messages:[{role:"user",content:$p}]}'
    fi
}

# Returns "seconds<TAB>completion_tokens<TAB>reply_first_40_chars"
timed_request() {
    local prompt="$1" body t0 t1 out
    body="$(payload "$prompt")"
    t0=$(python3 -c 'import time;print(time.time())')
    out=$(curl -s -m 600 "$URL/v1/chat/completions" \
        -H 'Content-Type: application/json' -d "$body")
    t1=$(python3 -c 'import time;print(time.time())')
    local secs ntok text
    secs=$(python3 -c "print(f'{$t1-$t0:.2f}')")
    ntok=$(printf '%s' "$out" | jq -r '.usage.completion_tokens // 0' 2>/dev/null || echo 0)
    text=$(printf '%s' "$out" | jq -r '.choices[0].message.content // "ERROR"' 2>/dev/null | head -c 40 | tr '\n' ' ')
    printf '%s\t%s\t%s' "$secs" "$ntok" "$text"
}

# Ollama can be told to drop a model immediately, which is the only way
# to measure a genuine cold start without restarting the server.
unload_ollama() {
    curl -s "$URL/api/generate" -H 'Content-Type: application/json' \
        -d "$(jq -n --arg m "$MODEL" '{model:$m, keep_alive:0}')" >/dev/null 2>&1
    sleep 3
}

printf 'label\tphase\tsecs\ttokens\ttok_per_s\tsample\n'

if [ "$UNLOAD" -eq 1 ]; then
    unload_ollama
    r=$(timed_request "Reply with exactly: OK")
    secs=$(printf '%s' "$r" | cut -f1)
    printf '%s\tcold\t%s\t-\t-\t%s\n' "$LABEL" "$secs" "$(printf '%s' "$r" | cut -f3)"
fi

# Warm short: the ":AIQuery quick question" feel.
best=""
for _ in $(seq 1 "$REPEAT"); do
    r=$(timed_request "Reply with exactly: OK")
    s=$(printf '%s' "$r" | cut -f1)
    if [ -z "$best" ] || python3 -c "import sys;sys.exit(0 if $s<$best else 1)"; then best="$s"; fi
done
printf '%s\twarm_short\t%s\t-\t-\t-\n' "$LABEL" "$best"

# Long generation: the ":AIReviewFile" feel. Throughput matters here.
LONG_PROMPT='Explain, in about 400 words, how a Vim plugin should structure a provider abstraction so that adding a new AI backend does not require changing the orchestrator.'
r=$(timed_request "$LONG_PROMPT")
secs=$(printf '%s' "$r" | cut -f1)
ntok=$(printf '%s' "$r" | cut -f2)
tps=$(python3 -c "
s=$secs; n=$ntok
print(f'{n/s:.1f}' if s>0 and n>0 else '-')")
printf '%s\tlong_gen\t%s\t%s\t%s\t%s\n' "$LABEL" "$secs" "$ntok" "$tps" "$(printf '%s' "$r" | cut -f3)"
