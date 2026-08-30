#!/usr/bin/env bash
# scripts/lib.sh
# Shared helpers. Source this; do not execute it.
#
# The two things worth knowing before editing anything here:
#
#   1. Headless Vim MUST have stdin on /dev/null. In `-es` mode any
#      prompt (an unhandled error, a "Press ENTER", a pager stop) reads
#      stdin and blocks forever with no output. Every vim invocation
#      here redirects stdin and is wrapped in a watchdog.
#
#   2. macOS ships no timeout(1). `with_timeout` below is a portable
#      replacement built from a background process and a poll loop, so
#      nothing needs coreutils installed.

set -uo pipefail

TESTING_DIR="${TESTING_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Where the plugin under test lives. This repo is deliberately separate
# from the plugin, so the default is the standard install location; a
# sandboxed unpack overrides it via VIMGEM_TEST_RTP (see install.sh).
PLUGIN_DIR="${PLUGIN_DIR:-${VIMGEM_TEST_RTP:-$HOME/.vim}}"
OUT_DIR="${OUT_DIR:-$TESTING_DIR/out}"
VIM_BIN="${VIM_BIN:-vim}"

mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------- output --
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
    C_DIM=$'\033[2m';  C_OFF=$'\033[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_DIM=''; C_OFF=''
fi

info() { printf '%s==>%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
pass() { printf '%sPASS%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
warn() { printf '%sWARN%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
fail() { printf '%sFAIL%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; }
die()  { fail "$*"; exit 1; }

# --------------------------------------------------------------- timeout --
# with_timeout SECONDS command...
# Exit status is the command's, or 124 if it was killed for running long
# (matching GNU timeout's convention so callers can special-case it).
with_timeout() {
    local secs="$1"; shift
    "$@" &
    local pid=$!
    local waited=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$waited" -ge "$secs" ]; then
            kill -TERM "$pid" 2>/dev/null
            sleep 1
            kill -KILL "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            return 124
        fi
        sleep 1
        waited=$((waited + 1))
    done
    wait "$pid"
}

# ------------------------------------------------------------------- vim --
# run_vim <script.vim> [extra vim args...]
#
# Runs a Vim script headlessly against the plugin. Honours:
#   VIMGEM_TEST_RTP   - if set, --clean plus this dir prepended to rtp,
#                       so a sandboxed unpack is tested instead of ~/.vim
#   VIMGEM_CHAT_HOME  - required; testrc.vim refuses to run without it
#   VIM_TIMEOUT       - watchdog seconds (default 120)
run_vim() {
    local script="$1"; shift
    local -a args=(-es --not-a-term -i NONE -u "$TESTING_DIR/vim/testrc.vim")
    [ -n "${VIMGEM_TEST_RTP:-}" ] && args=(--clean "${args[@]}")
    with_timeout "${VIM_TIMEOUT:-120}" \
        "$VIM_BIN" "${args[@]}" -S "$script" "$@" </dev/null
}

# ------------------------------------------------------------------ http --
# wait_for_http URL SECONDS -- poll until the endpoint answers.
wait_for_http() {
    local url="$1" secs="${2:-30}" i=0
    while [ "$i" -lt "$secs" ]; do
        curl -s -o /dev/null -m 2 "$url" && return 0
        i=$((i + 1)); sleep 1
    done
    return 1
}

http_up() { curl -s -o /dev/null -m 2 "$1"; }

# wait_for_ready BASE_URL SECONDS
#
# Use this, not wait_for_http, before benchmarking or testing a local
# server. llama-server answers GET /v1/models as soon as the socket is
# open -- BEFORE the weights finish loading -- so a models probe reports
# "up" several seconds early and the first real requests come back as
# errors. Only a completion round-trip proves the model is resident.
wait_for_ready() {
    local url="$1" secs="${2:-300}" i=0 body
    while [ "$i" -lt "$secs" ]; do
        body=$(curl -s -m 10 "$url/v1/chat/completions" \
            -H 'Content-Type: application/json' \
            -d '{"messages":[{"role":"user","content":"hi"}],"max_tokens":1}' 2>/dev/null)
        if printf '%s' "$body" | jq -e '.choices[0].message' >/dev/null 2>&1; then
            return 0
        fi
        i=$((i + 2)); sleep 2
    done
    return 1
}

# ------------------------------------------------------------------- tap --
# tap_summary <file> -- print counts, return non-zero if anything failed.
tap_summary() {
    local f="$1"
    local ok not_ok skip
    local todo
    ok=$(grep -c '^ok '     "$f" 2>/dev/null || true)
    # A "not ok" carrying "# TODO" is a known, filed defect: reported,
    # but deliberately not counted as a suite failure. See harness.vim Todo().
    not_ok=$(grep '^not ok ' "$f" 2>/dev/null | grep -vc '# TODO' || true)
    todo=$(grep -c '# TODO'  "$f" 2>/dev/null || true)
    skip=$(grep -c '# SKIP'  "$f" 2>/dev/null || true)
    printf '%s passed, %s failed, %s todo, %s skipped\n' \
        "${ok:-0}" "${not_ok:-0}" "${todo:-0}" "${skip:-0}"
    [ "${not_ok:-0}" -eq 0 ]
}
