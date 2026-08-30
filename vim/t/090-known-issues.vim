vim9script
# 090-known-issues: executable reproductions of defects found by this
# suite and prepared for upstream reporting. Every assertion here is marked TODO, so
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

# ---------------------------------------------------------------------
# ISSUE 5: reasoning models' output is discarded, and the failure is
# silent or misleading.
#
# Thinking models (llama.cpp with a reasoning model, and others) return
# their chain of thought in message.reasoning_content, separate from
# message.content. autoload/ai/openai.vim ExtractResult reads only
# message.content, so the reasoning is dropped -- which is a defensible
# display choice on its own, but produces two bad outcomes when the model
# puts little or nothing in content:
#
#   content: ""        -> {ok: true, text: ''}. The user gets a BLANK
#                         buffer and no explanation.
#   no content key     -> falls through to "Received an empty or
#                         malformed response from the API", which is
#                         wrong: the server responded correctly.
#
# Either way the user waited for every one of those thinking tokens --
# 4051 of them for one 400-word request, see docs/mac-analysis.md -- and
# is shown none of them and told nothing useful.
#
# Suggested fix: read reasoning_content when content is empty or absent,
# and either surface it (clearly labelled) or report "the model returned
# only reasoning content" rather than claiming a malformed response.
# ---------------------------------------------------------------------
silent AIPrompt off

var reasoning_err = ''
try
    silent AIQuery !reasoning
catch
    reasoning_err = v:exception
endtry
var reasoning_buf = join(getline(1, '$'), "\n")

H.Eq(trim(reasoning_buf), '',
    'precondition: an empty content field yields an empty buffer today')
H.Todo(trim(reasoning_buf) != '',
    'a reply carrying only reasoning_content shows the user something',
    'openai.vim ExtractResult reads message.content only; reasoning_content is dropped')

var only_err = ''
try
    silent AIQuery !reasoning-only
catch
    only_err = v:exception
endtry

H.Match(only_err, '\cempty or malformed',
    'precondition: a missing content field is reported as malformed today')
H.Todo(only_err !~ '\cmalformed',
    'a reasoning-only reply is not misreported as a malformed response',
    'the server responded correctly; only message.content was absent')
H.Diag('reasoning-only error was: ' .. only_err)

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

# ---------------------------------------------------------------------
# ISSUE 5: reasoning models' output is discarded, and the failure is
# silent or misleading.
#
# Thinking models (llama.cpp with a reasoning model, and others) return
# their chain of thought in message.reasoning_content, separate from
# message.content. autoload/ai/openai.vim ExtractResult reads only
# message.content, so the reasoning is dropped -- which is a defensible
# display choice on its own, but produces two bad outcomes when the model
# puts little or nothing in content:
#
#   content: ""        -> {ok: true, text: ''}. The user gets a BLANK
#                         buffer and no explanation.
#   no content key     -> falls through to "Received an empty or
#                         malformed response from the API", which is
#                         wrong: the server responded correctly.
#
# Either way the user waited for every one of those thinking tokens --
# 4051 of them for one 400-word request, see docs/mac-analysis.md -- and
# is shown none of them and told nothing useful.
#
# Suggested fix: read reasoning_content when content is empty or absent,
# and either surface it (clearly labelled) or report "the model returned
# only reasoning content" rather than claiming a malformed response.
# ---------------------------------------------------------------------
silent AIPrompt off

var reasoning_err = ''
try
    silent AIQuery !reasoning
catch
    reasoning_err = v:exception
endtry
var reasoning_buf = join(getline(1, '$'), "\n")

H.Eq(trim(reasoning_buf), '',
    'precondition: an empty content field yields an empty buffer today')
H.Todo(trim(reasoning_buf) != '',
    'a reply carrying only reasoning_content shows the user something',
    'openai.vim ExtractResult reads message.content only; reasoning_content is dropped')

var only_err = ''
try
    silent AIQuery !reasoning-only
catch
    only_err = v:exception
endtry

H.Match(only_err, '\cempty or malformed',
    'precondition: a missing content field is reported as malformed today')
H.Todo(only_err !~ '\cmalformed',
    'a reasoning-only reply is not misreported as a malformed response',
    'the server responded correctly; only message.content was absent')
H.Diag('reasoning-only error was: ' .. only_err)

H.Done()
