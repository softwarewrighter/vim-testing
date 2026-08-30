vim9script
# 100-live-smoke: compatibility checks against a REAL model server.
#
# The mock-backed files (030, 050-090) drive the server with `!echo` /
# `!count` / `!dump` directives, which no real model honours -- so they
# are meaningless against a live backend and the runner does not select
# them for one. This file is the live tier: it asserts only what is true
# of any competent model, and exists to answer one question the mock
# structurally cannot -- "does vimgem actually work against this server?"
#
# Assertions are deliberately loose about CONTENT (a reply arrived, it is
# non-empty, it is not an error) and strict about MECHANICS (files
# created, history grew, model recorded, buffers wired up).
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('live smoke', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

var model = getenv('VIMGEM_TEST_MODEL')
var home = getenv('VIMGEM_CHAT_HOME')

silent AIProvider openai
execute 'silent AIUrl ' .. base
if !empty(model)
    execute 'silent AIModel ' .. model
endif
silent AIPrompt off

H.Diag('server=' .. base .. ' model=' .. (empty(model) ? '(omitted)' : model))

# --- the server lists models -------------------------------------------
silent AIModels
var models_text = join(getline(1, '$'), "\n")
H.NoMatch(models_text, '\cError:', ':AIModels succeeds against the live server')
H.Diag('models listing: ' .. substitute(models_text, "\n", ' | ', 'g')[0 : 240])

# --- one-shot query -----------------------------------------------------
# Catch rather than let it abort: a live server that rejects the request
# must produce a readable TAP failure, not a bare "vim exit 1" with no
# output at all. (That is exactly how a missing model name presented.)
var t0 = reltime()
var query_err = ''
try
    silent AIQuery Reply with the single word: ready
catch
    query_err = v:exception
endtry
var elapsed = reltimefloat(reltime(t0))
H.Ok(empty(query_err), ':AIQuery completes without throwing')
if !empty(query_err)
    H.Diag('threw: ' .. query_err)
    H.Done()
endif
var reply = trim(join(getline(1, '$'), "\n"))
H.Ok(!empty(reply), ':AIQuery returns a non-empty reply')
H.NoMatch(reply, '^\cError\|^API Error', ':AIQuery reply is not an error')
H.Diag(printf(':AIQuery round trip: %.1fs, %d chars', elapsed, len(reply)))

# A real model may not obey "single word", but a wildly long answer to
# that prompt is a strong hint the server is ignoring instructions or
# leaking chain-of-thought -- worth surfacing, not worth failing on.
if len(reply) > 400
    H.Diag('NOTE: reply to a one-word prompt was ' .. len(reply)
        .. ' chars -- possibly a reasoning model. See docs/mac-analysis.md.')
endif

# --- multi-turn chat ----------------------------------------------------
silent AIChat
var chat_id = get(b:, 'ai_chat_id', '')
H.Ok(!empty(chat_id), ':AIChat opens a registered session')

append(line('$'), 'Answer in one short sentence: what is 2+2?')
var t1 = reltime()
silent AIChatSend
H.Diag(printf('turn 1 round trip: %.1fs', reltimefloat(reltime(t1))))

var js = home .. '/chat-' .. chat_id .. '.json'
H.Ok(filereadable(home .. '/chat-' .. chat_id .. '.md') > 0, 'transcript written')
H.Ok(filereadable(js) > 0, 'history written')
var hist = json_decode(join(readfile(js), "\n"))
H.Eq(len(hist), 2, 'history has one user + one assistant entry')
H.Ok(!empty(get(hist[1], 'text', '')), 'the assistant entry is non-empty')

# Second turn: the mechanics of resending history, without depending on
# the model to report anything back about it.
append(line('$'), 'And what is double that?')
silent AIChatSend
hist = json_decode(join(readfile(js), "\n"))
H.Eq(len(hist), 4, 'a second turn appends two more history entries')

var body = join(getline(1, '$'), "\n")
H.Match(body, '## AI', 'replies are rendered under an ## AI heading')
if !empty(model)
    H.Match(body, escape(model, '.*[]~/\'), 'the transcript records the model that answered')
endif

H.Done()
