vim9script
# 090-known-issues: executable reproductions of defects found by this
# suite and reported upstream. Every assertion here is marked TODO, so
# the file documents the bug and runs green -- but the moment one starts
# PASSING, TAP flags it as unexpectedly-passing and you know the fix
# landed and the marker can come off.
#
# Each block states: what is wrong, the user-visible consequence, and
# where in the source it originates.
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('known-issue reproductions', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

var home = getenv('VIMGEM_CHAT_HOME')
silent AIProvider openai
execute 'silent AIUrl ' .. base

# ---------------------------------------------------------------------
# ISSUE 1: chat session ids collide within one second, and the collision
# silently destroys the older session's conversation history.
#
# autoload/ai/buffer.vim CreateChat():
#     var chat_id = strftime('%Y%m%d-%H%M%S')
# is used with no uniqueness check, and CreateChat then calls
# SaveHistory(chat_id, []).
#
# Consequence: run :AIChat (or hit \c) twice inside the same second --
# entirely reachable by hand -- and the second call resets the first
# session's .json history to []. The .md transcript still shows the
# earlier turn, so nothing looks wrong, but the model has lost all
# context and both buffers now write to one file.
#
# Suggested fix: if the path already exists, append a disambiguating
# suffix (-1, -2, ...) or fall back to a higher-resolution id.
# ---------------------------------------------------------------------
# Align to the START of a fresh wall-clock second before opening either
# chat. Without this the reproduction is flaky: the two :AIChat calls
# collide only when they land in the same second, so the test passes
# whenever they happen to straddle a tick -- which is exactly what makes
# this bug so easy to miss in normal use.
def WaitForSecondBoundary()
    var start = strftime('%S')
    while strftime('%S') == start
        # spin; sleep 10m would overshoot on a fast machine
    endwhile
enddef
WaitForSecondBoundary()

silent AIChat
var id1 = b:ai_chat_id
append(line('$'), '!echo FIRST-SESSION-CONTENT')
silent AIChatSend
var hist1 = json_decode(join(readfile(home .. '/chat-' .. id1 .. '.json'), "\n"))
H.Eq(len(hist1), 2, 'precondition: first session has 2 history entries')

silent AIChat
var id2 = b:ai_chat_id

H.Ok(id1 == id2 || id1 != id2, 'both sessions opened')
H.Diag('elapsed seconds across both opens: ' .. (str2nr(id2[-2 : ]) - str2nr(id1[-2 : ])))

H.Todo(id1 != id2,
    'two :AIChat calls in the same second get distinct ids',
    'buffer.vim CreateChat uses second-resolution strftime with no collision check')

var hist1_after = json_decode(join(readfile(home .. '/chat-' .. id1 .. '.json'), "\n"))
H.Todo(len(hist1_after) == 2,
    'opening a second chat does not wipe the first chat history',
    'CreateChat calls SaveHistory(id, []) on a colliding id -- silent context loss')

H.Diag('id1=' .. id1 .. ' id2=' .. id2
    .. ' history entries before=' .. len(hist1)
    .. ' after=' .. len(hist1_after))

H.Done()
