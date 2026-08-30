#!/usr/bin/env bash
# scripts/run-tests.sh
# Run the headless Vim test suite.
#
#   ./run-tests.sh                  # mock backend (offline, fast, default)
#   ./run-tests.sh --backend ollama --model qwen2.5-coder:7b
#   ./run-tests.sh --backend live --url http://large12.local:8080
#   ./run-tests.sh --offline        # only tests needing no server at all
#   ./run-tests.sh 050-chat         # run one test by name fragment
#
# Exit status is 0 only if every assertion in every file passed.

set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

BACKEND=mock
BASE_URL=""
MODEL=""
FILTER=""
OFFLINE=0
MOCK_PORT="${MOCK_PORT:-9099}"

while [ $# -gt 0 ]; do
    case "$1" in
        --backend) BACKEND="$2"; shift 2 ;;
        --url)     BASE_URL="$2"; shift 2 ;;
        --model)   MODEL="$2"; shift 2 ;;
        --offline) OFFLINE=1; BACKEND=none; shift ;;
        --sandbox) export VIMGEM_TEST_RTP="$2"; shift 2 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *)         FILTER="$1"; shift ;;
    esac
done

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$OUT_DIR/run-$RUN_ID"
mkdir -p "$RUN_DIR"

# Isolation: never touch the user's real chat home. testrc.vim refuses
# to start if this is unset or points at the real one.
export VIMGEM_CHAT_HOME="$RUN_DIR/chat"
export VIMGEM_TEST_TMP="$RUN_DIR/tmp"
mkdir -p "$VIMGEM_CHAT_HOME" "$VIMGEM_TEST_TMP"

MOCK_PID=""
cleanup() {
    [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null
    return 0
}
trap cleanup EXIT

# ------------------------------------------------------------- backend --
case "$BACKEND" in
    none)
        info "backend: none (offline tests only)"
        ;;
    mock)
        export MOCK_LOG="$RUN_DIR/requests.jsonl"
        info "backend: mock on port $MOCK_PORT"
        python3 ./mock_openai.py --port "$MOCK_PORT" --log "$MOCK_LOG" \
            --models "mock-small,mock-large,mock-vision" \
            >"$RUN_DIR/mock.log" 2>&1 &
        MOCK_PID=$!
        wait_for_http "http://127.0.0.1:$MOCK_PORT/v1/models" 15 \
            || die "mock server did not come up; see $RUN_DIR/mock.log"
        BASE_URL="http://127.0.0.1:$MOCK_PORT"
        ;;
    ollama)
        BASE_URL="${BASE_URL:-http://localhost:11434}"
        http_up "$BASE_URL/v1/models" \
            || die "ollama is not answering at $BASE_URL -- run: just up-ollama"
        if [ -z "$MODEL" ]; then
            MODEL=$(curl -s "$BASE_URL/v1/models" | jq -r '.data[0].id')
        fi
        info "backend: ollama at $BASE_URL (model: $MODEL)"
        # Live models are slow and chatty; give each file room and expect
        # the prose-matching assertions to be less reliable than the mock's.
        export VIM_TIMEOUT="${VIM_TIMEOUT:-300}"
        ;;
    llamacpp|live)
        BASE_URL="${BASE_URL:-http://localhost:8080}"
        http_up "$BASE_URL/v1/models" \
            || die "no OpenAI-compatible server at $BASE_URL"
        # Pick a model only when the server actually needs one. A
        # single-model server (llama-server, mlx_lm.server) wants the
        # "model" field omitted entirely; a multi-model one (ollama,
        # vLLM) errors without a name. Count what is served and decide.
        if [ -z "$MODEL" ]; then
            n_models=$(curl -s -m 5 "$BASE_URL/v1/models" | jq -r '[.data[]?.id] | length')
            if [ "${n_models:-0}" -gt 1 ]; then
                MODEL=$(curl -s -m 5 "$BASE_URL/v1/models" | jq -r '.data[0].id')
                info "multi-model server ($n_models models); using $MODEL"
            else
                info "single-model server; omitting the model field"
            fi
        fi
        info "backend: $BACKEND at $BASE_URL"
        export VIM_TIMEOUT="${VIM_TIMEOUT:-300}"
        ;;
    *)
        die "unknown backend: $BACKEND (mock|ollama|llamacpp|live|none)"
        ;;
esac

[ -n "$BASE_URL" ] && export VIMGEM_TEST_BASE_URL="$BASE_URL"
[ -n "$MODEL" ]    && export VIMGEM_TEST_MODEL="$MODEL"

# --------------------------------------------------------------- files --
shopt -s nullglob
FILES=("$TESTING_DIR"/vim/t/*.vim)
if [ -n "$FILTER" ]; then
    MATCHED=()
    for f in "${FILES[@]}"; do
        case "$(basename "$f")" in *"$FILTER"*) MATCHED+=("$f") ;; esac
    done
    FILES=("${MATCHED[@]}")
    [ ${#FILES[@]} -eq 0 ] && die "no test file matches '$FILTER'"
fi
if [ "$OFFLINE" -eq 1 ]; then
    # 010/020 need no server; the rest self-skip when the URL is unset.
    MATCHED=()
    for f in "${FILES[@]}"; do
        case "$(basename "$f")" in 010-*|020-*) MATCHED+=("$f") ;; esac
    done
    FILES=("${MATCHED[@]}")
fi

# Tier selection. The mock-backed files drive the server with !echo /
# !count / !dump directives that no real model honours, so running them
# against a live backend would assert on gibberish. Live backends get the
# server-independent files plus 100-live-smoke; the mock gets everything
# except 100 (which would be redundant).
if [ -z "$FILTER" ]; then
    MATCHED=()
    for f in "${FILES[@]}"; do
        base_name="$(basename "$f")"
        case "$BACKEND" in
            mock)
                [ "${base_name#100-}" = "$base_name" ] && MATCHED+=("$f")
                ;;
            none)
                MATCHED+=("$f")
                ;;
            *)
                case "$base_name" in
                    010-*|020-*|040-*|100-*) MATCHED+=("$f") ;;
                esac
                ;;
        esac
    done
    FILES=("${MATCHED[@]}")
fi

# ----------------------------------------------------------------- run --
ALL_TAP="$RUN_DIR/all.tap"
: >"$ALL_TAP"
rc=0

for f in "${FILES[@]}"; do
    name="$(basename "$f" .vim)"
    tap="$RUN_DIR/$name.tap"
    export VIMGEM_TEST_TAP="$tap"
    : >"$tap"

    run_vim "$f" >"$RUN_DIR/$name.log" 2>&1
    vrc=$?

    if [ "$vrc" -eq 124 ]; then
        fail "$name TIMED OUT after ${VIM_TIMEOUT:-120}s"
        echo "not ok - $name (timeout)" >>"$ALL_TAP"
        rc=1
        continue
    fi

    if [ ! -s "$tap" ]; then
        # No TAP at all means Vim died before H.Done() -- usually a
        # syntax error or an uncaught throw. The log has the message.
        fail "$name produced no TAP (vim exit $vrc)"
        sed 's/^/    /' "$RUN_DIR/$name.log" | head -20 >&2
        echo "not ok - $name (no output)" >>"$ALL_TAP"
        rc=1
        continue
    fi

    sed "s/^/[$name] /" "$tap" >>"$ALL_TAP"
    if grep '^not ok ' "$tap" | grep -qv '# TODO'; then
        fail "$name -- $(tap_summary "$tap")"
        grep '^not ok ' "$tap" | grep -v '# TODO' | sed 's/^/    /' >&2
        rc=1
    else
        pass "$name -- $(tap_summary "$tap")"
        grep '# TODO' "$tap" | sed 's/^/    todo: /' || true
    fi
done

# The shell half of 080-wire: assert on the mock's request log. Only
# meaningful against the mock, which is the only backend that logs.
if [ "$BACKEND" = mock ] && [ -s "${MOCK_LOG:-}" ]; then
    wire_tap="$RUN_DIR/wire.tap"
    if ./assert-wire.sh "$MOCK_LOG" >"$wire_tap" 2>&1; then
        pass "wire-shape -- $(tap_summary "$wire_tap")"
    else
        fail "wire-shape -- $(tap_summary "$wire_tap")"
        grep '^not ok ' "$wire_tap" | sed 's/^/    /' >&2
        rc=1
    fi
    sed 's/^/[wire-shape] /' "$wire_tap" >>"$ALL_TAP"
fi

echo
info "TAP: $ALL_TAP"
info "artifacts: $RUN_DIR"
[ "$rc" -eq 0 ] && pass "all tests passed" || fail "suite failed"
exit $rc
