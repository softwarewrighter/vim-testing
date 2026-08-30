vim9script
# 030-query: one-shot :AIQuery against the mock server.
# Covers the happy path plus the response shapes vimgem has to
# distinguish (see openai.vim ExtractResult): truncation, an error
# object in a 200 body, a non-2xx status, and unparseable output.
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('query tests', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

silent AIProvider openai
execute 'silent AIUrl ' .. base
silent AIPrompt off

def Ask(prompt: string): string
    execute 'silent AIQuery ' .. prompt
    return join(getline(1, '$'), "\n")
enddef

# --- happy path ---------------------------------------------------------
H.Match(Ask('!echo PINEAPPLE'), 'PINEAPPLE', ':AIQuery returns the reply')

# With show_prompt off the buffer is the bare response: no provider or
# model header should leak in.
H.NoMatch(Ask('!echo BARE'), 'Provider:\|Model:',
    ':AIPrompt off suppresses the header')

# --- show_prompt on -----------------------------------------------------
silent AIPrompt on
var withhdr = Ask('!echo HEADERED')
H.Match(withhdr, 'HEADERED', 'reply still present with show_prompt on')
H.Match(withhdr, '!echo HEADERED', 'original prompt echoed with show_prompt on')
silent AIPrompt off

# --- truncation ---------------------------------------------------------
# finish_reason == "length" is the only truncation signal this protocol
# offers; the user must be told, or a silently cut-off answer looks
# complete.
var trunc_msgs = H.Messages('AIQuery !truncate')
var trunc_buf = join(getline(1, '$'), "\n")
H.Match(trunc_buf, 'cut off mid-', 'truncated reply body is still delivered')

# ISSUE 2 (see 090-known-issues and docs/test-plan.md "Findings"):
# core.vim ~line 157 announces truncation with a bare :echo. That message
# is transient -- one keystroke and it is gone -- and it leaves no trace
# in the output buffer, so a user who looks away cannot tell a cut-off
# answer from a complete one. The write-target path already does this
# properly (core.vim ~line 284 inlines a "[Warning: Response was
# truncated...]" line); :AIQuery should do the same.
#
# It is also invisible to automation: under `vim -es` (silent mode) :echo
# output is suppressed and never reaches :redir, which is why the capture
# below is empty rather than merely unmatched.
H.Todo(trunc_buf =~ '\c\[Warning.*truncat',
    'truncation is recorded in the :AIQuery output buffer',
    'core.vim uses a transient :echo; the write-target path inlines a warning line instead')
H.Diag('captured messages: ' .. string(trunc_msgs))

# --- error paths --------------------------------------------------------
H.Throws('AIQuery !status 500', '\c500\|error', 'HTTP 500 surfaces as an error')
H.Throws('AIQuery !apierror deliberate-mock-failure', 'deliberate-mock-failure',
    'error object in a 200 body surfaces with the server message')
H.Throws('AIQuery !badjson', '\cjson\|pars\|malformed',
    'unparseable response surfaces as an error')

H.Done()
