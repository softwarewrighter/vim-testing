#!/usr/bin/env bash
# scripts/assert-wire.sh
# Assert on what vimgem actually put on the wire, by reading the mock
# server's request log.
#
# This is the shell half of the pair whose Vim half is vim/t/080-wire.vim.
# Split deliberately: the Vim side asserts that a request SUCCEEDS, this
# side asserts that it had the right SHAPE. A change in either the request
# payload or the log format then fails loudly instead of quietly passing.
#
# Usage: ./assert-wire.sh <requests.jsonl>
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

LOG="${1:-}"
[ -n "$LOG" ] && [ -f "$LOG" ] || die "usage: assert-wire.sh <requests.jsonl>"

count=0
failed=0
tap=()

check() {
    local name="$1" cond="$2"
    count=$((count + 1))
    if [ "$cond" = "1" ]; then
        tap+=("ok $count - $name")
    else
        failed=$((failed + 1))
        tap+=("not ok $count - $name")
    fi
}

posts=$(jq -c 'select(.method == "POST")' "$LOG" 2>/dev/null)
[ -n "$posts" ] || die "no POST requests in $LOG"

# --- the "model" field is omitted when no model is configured ----------
# vimgem deliberately omits the key entirely rather than sending an empty
# string (openai.vim ExecuteChatRequest): mlx_lm.server and other
# single-model servers expect that, and some servers will try to FETCH a
# model name they do not recognise.
n_absent=$(printf '%s\n' "$posts" | jq -s '[.[] | select(.model_present == false)] | length')
check "at least one request omitted the model field entirely" \
      "$([ "$n_absent" -gt 0 ] && echo 1 || echo 0)"

# An empty-string model must never be sent -- that is the failure mode
# omitting the key exists to avoid.
n_empty=$(printf '%s\n' "$posts" | jq -s '[.[] | select(.model_present == true and (.model == "" or .model == null))] | length')
check "no request sent an empty-string model field" \
      "$([ "$n_empty" -eq 0 ] && echo 1 || echo 0)"

# --- a configured model IS sent ----------------------------------------
n_named=$(printf '%s\n' "$posts" | jq -s '[.[] | select(.model_present == true and .model != "")] | length')
check "at least one request carried a real model name" \
      "$([ "$n_named" -gt 0 ] && echo 1 || echo 0)"

# --- API key becomes a bearer header, and only when set ----------------
n_bearer=$(printf '%s\n' "$posts" | jq -s '[.[] | select(.authorization != null and (.authorization | startswith("Bearer ")))] | length')
check "a configured API key is sent as an Authorization: Bearer header" \
      "$([ "$n_bearer" -gt 0 ] && echo 1 || echo 0)"

n_noauth=$(printf '%s\n' "$posts" | jq -s '[.[] | select(.authorization == null)] | length')
check "requests with no API key send no Authorization header" \
      "$([ "$n_noauth" -gt 0 ] && echo 1 || echo 0)"

# --- chat history really is resent -------------------------------------
# Some request must carry more than one message, or :AIChatSend is not
# sending context at all.
max_msgs=$(printf '%s\n' "$posts" | jq -s '[.[].n_messages] | max')
check "a chat turn resent prior context (max messages in one request > 1)" \
      "$([ "${max_msgs:-0}" -gt 1 ] && echo 1 || echo 0)"

# --- roles are only ever user/assistant --------------------------------
n_badrole=$(printf '%s\n' "$posts" | jq -s '[.[].messages[]? | select(.role != "user" and .role != "assistant" and .role != "system")] | length')
check "every message used a valid role" \
      "$([ "$n_badrole" -eq 0 ] && echo 1 || echo 0)"

printf '1..%d\n' "$count"
printf '%s\n' "${tap[@]}"
printf '# %s POSTs inspected; model absent=%s named=%s bearer=%s max_msgs=%s\n' \
    "$(printf '%s\n' "$posts" | wc -l | tr -d ' ')" \
    "$n_absent" "$n_named" "$n_bearer" "${max_msgs:-0}"

exit $([ "$failed" -eq 0 ] && echo 0 || echo 1)
