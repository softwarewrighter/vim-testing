# testing/vhs/_common.tape -- shared settings for every recording.
# Sourced with `Source "_common.tape"` at the top of each tape.
#
# Layout:
#   testing/vhs/*.tape    these sources
#   testing/videos/*.webm the deliverable -- scrubbable, pausable, ENDS
#   testing/gifs/*.gif    the same take as a GIF, for inline embedding
#
# Two rules for anyone editing these, both learned by ruining a take:
#
#  1. Narration is only ever typed at a SHELL prompt, where a leading `#`
#     makes it a harmless comment. Typing narration while Vim is running
#     inserts it into the buffer.
#
#  2. Never Sleep through a model response. Use
#       Wait+Screen@<timeout> /regex/
#     to continue the instant the screen shows the response arrived. A
#     fixed Sleep either cuts a slow model off or leaves dead air after a
#     fast one -- and the dead air is what makes a recording tedious.
Set Shell "bash"
Set FontSize 18
Set Width 1400
Set Height 800
Set Padding 20
Set TypingSpeed 55ms
Set Theme "Catppuccin Mocha"
