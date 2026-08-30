# vhs/_common.tape -- shared settings for every recording.
# Sourced with `Source "_common.tape"` at the top of each tape.
#
# Layout:
#   vhs/*.tape     these sources
#   videos/*.webm  the deliverable -- scrubbable, pausable, ENDS
#   gifs/*.gif     the same take as a GIF that plays once
#
# ---------------------------------------------------------------------
# PACING -- the thing most likely to be wrong. Read this before editing
# any Sleep value.
# ---------------------------------------------------------------------
# Reference rates: average adult silent reading of prose is ~240 wpm, and
# subtitle standards target 160-180 wpm. Terminal output is slower than
# prose -- it is dense with paths, URLs and identifiers that cannot be
# predicted from context -- but it is also SCANNED rather than read
# linearly: you look for the line that changed, not all 98 words of
# :AIInfo. So holds are sized for "scan the screen, read the part that
# matters" at roughly 130 wpm, with a floor and a ceiling.
#
# The vocabulary below is DERIVED from 130 wpm plus ~1s to reorient
# after the screen changes, counting only the salient words on a screen
# (you read the three config lines of :AIInfo, not all 98 of its words):
#
#   Sleep 4s       a command echoing its one-line confirmation, ~6 words
#                  (":AIProvider openai" -> "AI provider set to: openai")
#   Sleep 7s       one or two lines of shell narration, ~12 words
#   Sleep 11s      a screen to scan: just status, ~22 salient words
#   Sleep 15s      a dense screen to read: :AIInfo, :AIModels, ~30 words
#   Sleep 25s/35s  waiting on a model. NOT a read time -- an upper bound
#                  so a slow model is never cut off. The trim collapses
#                  whatever is left over into a real read pause.
#
# These are long by demo convention and deliberately so: the point is to
# be followable, not brisk. The .webm exists for anyone who wants to
# scrub past.
#
# --cap in render-videos.sh must stay just ABOVE the longest hold here
# (15s) so every deliberate pause survives untouched, while the leftover
# of a model wait -- which has no fixed length -- is capped to the same
# ~15s a dense screen gets. It defaults to 16s. It only ever SHORTENS a
# pause, never lengthens one.
#
# ---------------------------------------------------------------------
# Two further rules, both learned by ruining a take:
#
#  1. Narration is only ever typed at a SHELL prompt, where a leading `#`
#     makes it a harmless comment. Typing narration while Vim is running
#     inserts it into the buffer.
#
#  2. Never Sleep a fixed short time through a model response -- use the
#     generous upper bound above and let the trim handle it.
Set Shell "bash"
Set FontSize 18
Set Width 1400
Set Height 800
Set Padding 20

# ~90ms/char is about 130 wpm of typing -- a fast human, matched to the
# reading rate above. 55ms (the previous value) reads as a machine.
Set TypingSpeed 90ms
Set Theme "Catppuccin Mocha"
