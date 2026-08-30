#!/usr/bin/env bash
# scripts/providers.sh
# Bring local OpenAI-compatible backends up and down, and report what is
# reachable. vimgem talks to all of them through the one `openai`
# provider, so switching backend is only ever a base-URL change.
#
#   ./providers.sh status
#   ./providers.sh up ollama
#   ./providers.sh up llamacpp ~/tmp-hf/model.gguf [port]
#   ./providers.sh up mock [port]
#   ./providers.sh down llamacpp|mock
#   ./providers.sh url ollama          # print the base URL for :AIUrl
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
LLAMACPP_URL="${LLAMACPP_URL:-http://127.0.0.1:8080}"
MOCK_URL="${MOCK_URL:-http://127.0.0.1:9099}"
VLLM_URL="${VLLM_URL:-http://127.0.0.1:8000}"
REMOTE_URL="${REMOTE_URL:-http://large12.local:11434}"

pidfile() { echo "$OUT_DIR/$1.pid"; }

status_one() {
    local name="$1" url="$2"
    if http_up "$url/v1/models"; then
        local models
        models=$(curl -s -m 3 "$url/v1/models" \
            | jq -r '[.data[]?.id] | join(", ")' 2>/dev/null)
        printf '  %-10s %-32s %sUP%s   %s\n' "$name" "$url" "$C_GRN" "$C_OFF" "${models:-（no model list）}"
    else
        printf '  %-10s %-32s %sdown%s\n' "$name" "$url" "$C_DIM" "$C_OFF"
    fi
}

cmd_status() {
    echo "Local OpenAI-compatible backends:"
    status_one ollama   "$OLLAMA_URL"
    status_one llamacpp "$LLAMACPP_URL"
    status_one vllm     "$VLLM_URL"
    status_one mock     "$MOCK_URL"
    status_one remote   "$REMOTE_URL"
    echo
    echo "Cloud providers (env-var credentials):"
    printf '  %-10s %s\n' gemini "$([ -n "${GOOGLE_API_KEY:-}" ]    && echo 'GOOGLE_API_KEY set'    || echo 'GOOGLE_API_KEY not set')"
    printf '  %-10s %s\n' claude "$([ -n "${ANTHROPIC_API_KEY:-}" ] && echo 'ANTHROPIC_API_KEY set' || echo 'ANTHROPIC_API_KEY not set')"
}

cmd_up() {
    local what="${1:-}"; shift || true
    case "$what" in
        ollama)
            if http_up "$OLLAMA_URL/v1/models"; then
                info "ollama already serving at $OLLAMA_URL"; return 0
            fi
            command -v ollama >/dev/null || die "ollama is not installed (brew install ollama)"
            info "starting ollama serve"
            ollama serve >"$OUT_DIR/ollama.log" 2>&1 &
            echo $! >"$(pidfile ollama)"
            wait_for_http "$OLLAMA_URL/v1/models" 30 || die "ollama did not come up"
            pass "ollama up at $OLLAMA_URL"
            ;;
        llamacpp)
            local model="${1:-}" port="${2:-8080}"
            [ -n "$model" ] || die "usage: providers.sh up llamacpp <model.gguf> [port]"
            [ -f "$model" ] || die "no such model file: $model"
            command -v llama-server >/dev/null || die "llama-server not installed (brew install llama.cpp)"
            info "starting llama-server on port $port with $(basename "$model")"
            # -ngl 99 offloads every layer to the Metal GPU; on Apple
            # silicon that is the difference between usable and not.
            llama-server -m "$model" --host 127.0.0.1 --port "$port" \
                -c 8192 -ngl 99 >"$OUT_DIR/llamacpp.log" 2>&1 &
            echo $! >"$(pidfile llamacpp)"
            # NOT wait_for_http: llama-server opens its socket before the
            # weights are loaded. See lib.sh wait_for_ready.
            wait_for_ready "http://127.0.0.1:$port" 300 \
                || die "llama-server never became ready; see $OUT_DIR/llamacpp.log"
            pass "llama-server ready at http://127.0.0.1:$port"
            ;;
        mock)
            local port="${1:-9099}"
            python3 ./mock_openai.py --port "$port" --log "$OUT_DIR/requests.jsonl" \
                >"$OUT_DIR/mock.log" 2>&1 &
            echo $! >"$(pidfile mock)"
            wait_for_http "http://127.0.0.1:$port/v1/models" 15 || die "mock did not come up"
            pass "mock up at http://127.0.0.1:$port"
            ;;
        *) die "usage: providers.sh up ollama|llamacpp|mock" ;;
    esac
}

cmd_down() {
    local what="${1:-}"
    local pf; pf="$(pidfile "$what")"
    if [ -f "$pf" ]; then
        kill "$(cat "$pf")" 2>/dev/null && pass "stopped $what"
        rm -f "$pf"
    else
        warn "no pidfile for $what (was it started by this script?)"
    fi
}

cmd_url() {
    case "${1:-}" in
        ollama)   echo "$OLLAMA_URL" ;;
        llamacpp) echo "$LLAMACPP_URL" ;;
        vllm)     echo "$VLLM_URL" ;;
        mock)     echo "$MOCK_URL" ;;
        remote)   echo "$REMOTE_URL" ;;
        *) die "usage: providers.sh url ollama|llamacpp|vllm|mock|remote" ;;
    esac
}

case "${1:-status}" in
    status) cmd_status ;;
    up)     shift; cmd_up "$@" ;;
    down)   shift; cmd_down "$@" ;;
    url)    shift; cmd_url "$@" ;;
    *)      sed -n '2,14p' "$0"; exit 1 ;;
esac
