#!/usr/bin/env python3
"""
scripts/trim_static.py

Cap how long the screen may sit unchanged, without touching anything that
is actually moving.

Why not ffmpeg's mpdecimate
---------------------------
mpdecimate looked like the tool for this and is not. Its `max` parameter
caps how many CONSECUTIVE frames may be DROPPED -- so a larger value is
*more* aggressive, not less, and a long static run collapses to roughly
one frame in `max`. Used to "cap static runs at 2.5s" it instead crushed
a 200-frame pause down to about five frames, flashing a 98-word screen
past in a fraction of a second. Raising the value made it worse.

What this does instead
----------------------
Decode the video once at low resolution, measure how much each frame
differs from the one before, and treat runs below a threshold as static.
Every static run longer than --cap is truncated to exactly --cap seconds;
everything else is passed through untouched. The result is a list of
time ranges to keep, handed to ffmpeg as a single select expression.

So a deliberate 8s reading pause survives intact when --cap is 9, while
30s of waiting on a model becomes 9s. Model-speed-agnostic, and it can
never speed up a pause below the cap.

Usage:
    trim_static.py IN.webm OUT.webm [--cap 9] [--threshold 1.2] [--dry-run]
"""

import argparse
import subprocess
import sys

# Frames are compared at this width; height follows the aspect ratio.
# Small enough to be fast, large enough that a single changed line of
# terminal text still registers.
PROBE_W = 213

# Picking --threshold
# -------------------
# Measured over a real recording: 2085 of 2728 frames diff to EXACTLY
# zero. There is no blinking cursor in these captures, so a genuinely
# unchanged screen is byte-identical and anything nonzero is real motion.
# Typing a single character lands around 0.008-0.084 on this scale; a
# screen clear is ~15. So the threshold only has to clear float noise.
#
# Set it too high and typing is misread as "static" and truncated -- an
# earlier pass used 1.2, roughly a thousand times too high, which ate the
# typing animation along with the pauses.


def probe(path, entries):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", entries, "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True, check=True).stdout.split()
    return out


def frame_diffs(path, width, height, fps):
    """Yield the mean absolute difference between each frame and the last."""
    cmd = ["ffmpeg", "-v", "error", "-i", path,
           "-vf", f"scale={width}:{height},format=gray",
           "-f", "rawvideo", "-"]
    size = width * height
    prev = None
    with subprocess.Popen(cmd, stdout=subprocess.PIPE) as p:
        while True:
            buf = p.stdout.read(size)
            if len(buf) < size:
                break
            if prev is not None:
                # Mean abs diff over the frame, in 0..255 units.
                total = 0
                for a, b in zip(buf, prev):
                    total += a - b if a > b else b - a
                yield total / size
            else:
                yield 255.0          # first frame always counts as change
            prev = buf


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--cap", type=float, default=9.0,
                    help="max seconds the screen may sit unchanged")
    ap.add_argument("--threshold", type=float, default=0.001,
                    help="mean abs frame difference below which a frame "
                         "counts as unchanged (0-255 scale)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    w, h = (int(x) for x in probe(args.src, "stream=width,height"))
    rate = probe(args.src, "stream=r_frame_rate")[0]
    num, den = (int(x) for x in rate.split("/"))
    fps = num / den if den else num

    ph = max(2, round(PROBE_W * h / w / 2) * 2)
    diffs = list(frame_diffs(args.src, PROBE_W, ph, fps))
    n = len(diffs)
    if n == 0:
        sys.exit(f"trim_static: no frames decoded from {args.src}")

    cap_frames = max(1, int(round(args.cap * fps)))

    # Walk the frames, collecting the indices to keep. A run of frames
    # whose diff stays under the threshold is static; keep at most
    # cap_frames of it.
    keep = []
    i = 0
    while i < n:
        if diffs[i] >= args.threshold:
            keep.append(i)
            i += 1
            continue
        j = i
        while j < n and diffs[j] < args.threshold:
            j += 1
        run = j - i
        keep.extend(range(i, i + min(run, cap_frames)))
        i = j

    # Collapse the kept indices into contiguous time ranges.
    ranges = []
    start = prev = None
    for idx in keep:
        if start is None:
            start = prev = idx
        elif idx == prev + 1:
            prev = idx
        else:
            ranges.append((start, prev))
            start = prev = idx
    if start is not None:
        ranges.append((start, prev))

    kept_s = len(keep) / fps
    print(f"  {n} frames ({n/fps:.1f}s) -> {len(keep)} ({kept_s:.1f}s) "
          f"in {len(ranges)} ranges, cap={args.cap}s", file=sys.stderr)

    if args.dry_run:
        return

    # One select expression over half-open time ranges. Using frame
    # indices converted to times keeps this exact at the source fps.
    terms = "+".join(
        f"between(t,{a/fps:.4f},{(b + 1)/fps:.4f})" for a, b in ranges)
    vf = f"select='{terms}',setpts=N/FRAME_RATE/TB"

    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", args.src,
         "-vf", vf, "-r", f"{fps:g}",
         "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "32",
         "-row-mt", "1", "-an", args.dst],
        check=True)


if __name__ == "__main__":
    main()
