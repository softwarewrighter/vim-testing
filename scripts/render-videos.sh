#!/usr/bin/env bash
# scripts/render-videos.sh
# Record the VHS tapes and post-process them into the deliverables.
#
#   vhs/*.tape     -> source
#   out/raw/*.webm -> VHS's raw recording (kept for debugging)
#   videos/*.webm  -> the deliverable: scrubbable, pausable, ENDS
#   gifs/*.gif     -> same take as a GIF that plays ONCE
#
# Why post-processing exists
# --------------------------
# A tape has to Sleep long enough that the slowest model it might run
# against is never cut off mid-reply. Against a fast model that same
# Sleep leaves the viewer staring at a finished screen for 20 seconds.
#
# VHS's own `Wait+Screen` would have solved this at record time, but it
# reliably reads an empty screen once Vim is running (Vim's alternate
# screen buffer), so it is unusable here.
#
# Instead: record with generous Sleeps, then cap every STATIC run to
# STATIC_CAP seconds with ffmpeg's mpdecimate. Frames where nothing
# changed are dropped, but only up to `max` consecutive ones, so a pause
# is shortened rather than erased. This is model-speed-agnostic: the same
# tape gives a tight recording whether the reply took 1s or 60s.
#
# Usage: ./render-videos.sh [tape-name ...]     (default: all)
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

VHS_DIR="$TESTING_DIR/vhs"
RAW_DIR="$OUT_DIR/raw"
VID_DIR="$TESTING_DIR/videos"
GIF_DIR="$TESTING_DIR/gifs"
mkdir -p "$RAW_DIR" "$VID_DIR" "$GIF_DIR"

# Longest a static screen may remain, in seconds. Long enough to read a
# buffer, short enough that waiting for a model is not tedious.
STATIC_CAP="${STATIC_CAP:-2.5}"
# GIF width; the webm keeps VHS's full resolution.
GIF_WIDTH="${GIF_WIDTH:-1000}"

command -v vhs    >/dev/null || die "vhs not installed -- run: just install-tools"
command -v ffmpeg >/dev/null || die "ffmpeg not installed -- run: just install-tools"

tapes=()
if [ $# -gt 0 ]; then
    for n in "$@"; do tapes+=("$VHS_DIR/${n%.tape}.tape"); done
else
    shopt -s nullglob
    for t in "$VHS_DIR"/*.tape; do
        [ "$(basename "$t")" = "_common.tape" ] && continue
        tapes+=("$t")
    done
fi
[ ${#tapes[@]} -gt 0 ] || die "no tapes found in $VHS_DIR"

rc=0
for tape in "${tapes[@]}"; do
    name="$(basename "$tape" .tape)"
    raw="$RAW_DIR/$name.webm"

    info "recording $name"
    # VHS resolves Source and Output relative to the tape's directory.
    ( cd "$VHS_DIR" && vhs "$(basename "$tape")" ) >"$OUT_DIR/$name.vhs.log" 2>&1
    if [ ! -s "$raw" ]; then
        fail "$name: vhs produced no output; see $OUT_DIR/$name.vhs.log"
        tail -5 "$OUT_DIR/$name.vhs.log" | sed 's/^/    /' >&2
        rc=1
        continue
    fi

    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
          -of csv=p=0 "$raw" | awk -F/ '{printf "%d", ($2?$1/$2:$1)}')
    [ "${fps:-0}" -gt 0 ] || fps=25
    maxdrop=$(python3 -c "print(int($fps * $STATIC_CAP))")

    before=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$raw")

    # --- the deliverable: trimmed webm ---------------------------------
    ffmpeg -y -loglevel error -i "$raw" \
        -vf "mpdecimate=max=$maxdrop,setpts=N/FRAME_RATE/TB" -r "$fps" \
        -c:v libvpx-vp9 -b:v 0 -crf 32 -row-mt 1 -an \
        "$VID_DIR/$name.webm" || { fail "$name: webm encode failed"; rc=1; continue; }

    # --- the same take as a GIF that PLAYS ONCE ------------------------
    # -loop -1 omits the NETSCAPE2.0 application extension entirely, so
    # viewers play it through and stop instead of looping forever.
    palette="$OUT_DIR/$name-palette.png"
    ffmpeg -y -loglevel error -i "$VID_DIR/$name.webm" \
        -vf "fps=12,scale=$GIF_WIDTH:-1:flags=lanczos,palettegen=stats_mode=diff" \
        "$palette" 2>/dev/null
    ffmpeg -y -loglevel error -i "$VID_DIR/$name.webm" -i "$palette" \
        -lavfi "fps=12,scale=$GIF_WIDTH:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        -loop -1 "$GIF_DIR/$name.gif" 2>/dev/null
    rm -f "$palette"

    after=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VID_DIR/$name.webm")
    pass "$(printf '%-14s %5.1fs -> %5.1fs  webm %5.1fMB  gif %5.1fMB' "$name" \
        "$before" "$after" \
        "$(du -k "$VID_DIR/$name.webm" | cut -f1 | awk '{print $1/1024}')" \
        "$(du -k "$GIF_DIR/$name.gif"  | cut -f1 | awk '{print $1/1024}')")"
done

echo
info "videos: $VID_DIR"
info "gifs:   $GIF_DIR (non-looping)"
exit $rc
