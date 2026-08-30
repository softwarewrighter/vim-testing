#!/usr/bin/env bash
# scripts/check-deps.sh
# Report what is installed, split by what it is actually needed for, so a
# missing optional tool never looks like a broken setup.
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

row() {
    local tier="$1" name="$2" why="$3" path
    if path=$(command -v "$name" 2>/dev/null); then
        printf '  %s%-7s%s %-13s %s%s%s\n' "$C_DIM" "$tier" "$C_OFF" "$name" "$C_GRN" "$path" "$C_OFF"
    else
        local colour="$C_RED"; [ "$tier" = optional ] && colour="$C_YEL"
        printf '  %s%-7s%s %-13s %sMISSING%s -- %s\n' "$C_DIM" "$tier" "$C_OFF" "$name" "$colour" "$C_OFF" "$why"
    fi
}

echo "vimgem testing -- dependencies"
echo
echo "Required (the plugin and the batch suite):"
row required vim    'the editor under test'
row required curl   'vimgem shells out to curl for every API call'
row required python3 'mock server, timing arithmetic'
row required jq     'reading model lists and API responses'

echo
echo "Recommended (task runner and local backends):"
row rec just    'the task runner these recipes are written for'
row rec ollama  'easiest multi-model local backend'
row rec llama-server 'llama.cpp server; brew install llama.cpp'

echo
echo "Optional (extras that degrade gracefully if absent):"
row optional expect 'interactive TTY tests -- just test-interactive'
row optional vhs    'demo recordings -- just videos'
row optional ttyd   'vhs needs this to drive a terminal'
row optional ffmpeg 'vhs needs this to encode gif/mp4'

echo
printf 'vim: '
if vim --version 2>/dev/null | head -1 | grep -q .; then
    vim --version | head -1
    if vim --version | grep -q 'patch-9.1\|Included patches: 1-[0-9]'; then
        major=$(vim --version | head -1 | sed -n 's/.*IMproved \([0-9]*\.[0-9]*\).*/\1/p')
        awk -v v="$major" 'BEGIN{exit (v+0 >= 9.1) ? 0 : 1}' \
            && pass "Vim $major satisfies the 9.1+ requirement (vim9script classes)" \
            || fail "Vim $major is too old; vimgem needs 9.1+"
    fi
else
    fail "vim not found"
fi

echo
echo "Plugin:"
if [ -f "$PLUGIN_DIR/plugin/ai.vim" ]; then
    ver=$(sed -n "s/.*g:vimgem_version = '\([^']*\)'.*/\1/p" "$PLUGIN_DIR/plugin/ai.vim" | head -1)
    pass "found at $PLUGIN_DIR (version ${ver:-unknown})"
else
    fail "no plugin/ai.vim under $PLUGIN_DIR"
fi
