vim9script
# 070-references: {=...=} reference directives.
#
# These are the plugin's most distinctive feature and the easiest to
# regress, because expansion happens in one pass over the ORIGINAL prompt
# and a partial expansion must never be sent. The mock's !dump directive
# echoes back exactly what arrived, so these tests assert on the wire
# content rather than on the rendered reply.
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('reference tests', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

var tmp = getenv('VIMGEM_TEST_TMP')
silent AIProvider openai
execute 'silent AIUrl ' .. base
silent AIPrompt off

# A fixture file to reference by name.
var fixture = tmp .. '/ref-fixture.txt'
writefile(['alpha', 'bravo', 'charlie', 'delta', 'echo'], fixture)

def Send(question: string): string
    append(line('$'), split(question, "\n"))
    silent AIChatSend
    return join(getline(1, '$'), "\n")
enddef

# --- register reference {='a=} -----------------------------------------
setreg('a', "REGISTER-PAYLOAD-42")
silent AIChat
var body = Send('!dump' .. "\n" .. "{='a=}")
H.Match(body, 'REGISTER-PAYLOAD-42', "{='a=} expands the register into the prompt")

# --- ranged buffer/file reference {=1,3<'a>=} --------------------------
setreg('a', fixture)
body = Send("!dump\n{=1,3<'a>=}")
H.Match(body, 'alpha', "{=1,3<'a>=} includes line 1")
H.Match(body, 'charlie', "{=1,3<'a>=} includes line 3")
H.NoMatch(body, 'delta', "{=1,3<'a>=} stops at line 3")

# --- whole-file direct reference {=<name=} -----------------------------
body = Send('!dump' .. "\n" .. '{=<' .. fixture .. '=}')
H.Match(body, 'alpha', '{=<file=} inlines the file')
H.Match(body, 'echo', '{=<file=} inlines the whole file')
H.Match(body, '\[ID: ', '{=<file=} adds the [ID: name] round-trip instruction')

# --- failed reference aborts the whole send ----------------------------
# A missing file must abort rather than send a half-expanded prompt.
setreg('a', tmp .. '/definitely-does-not-exist.txt')
append(line('$'), "!dump\n{=1,3<'a>=}")
H.Throws('AIChatSend', '\cfail\|unreadable\|not found\|cannot\|error\|read',
    'an unresolvable reference aborts the send')

# --- model never sees plugin syntax ------------------------------------
# Write-target directives are stripped before the prompt is sent.
# The transcript legitimately echoes back what you typed, directives and
# all, so scope this assertion to the model's reply -- which for !dump is
# a verbatim record of what actually went over the wire.
#
# The sleep is not cosmetic: without it :AIChat collides with the session
# above (see 090-known-issues) and reopens the SAME file, which still
# holds the deliberately-unresolvable reference from the previous block --
# so the "new" chat fails on the old chat's text. Real bug, real bite.
sleep 1100m
setreg('a', fixture)
silent AIChat
append(line('$'), ['!dump', 'question text {=>scratch-target=}'])
silent AIChatSend

# The reply is diverted to the named buffer, so the transcript holds only
# a summary line -- assert that too, since it is the documented behaviour.
H.Match(join(getline(1, '$'), "\n"), "-> wrote to 'scratch-target'",
    '{=>name=} reports the write in the transcript instead of inlining the reply')

var target = bufnr('scratch-target')
H.Ok(target > 0, '{=>name=} creates the named target buffer')
var sent = target > 0 ? join(getbufline(target, 1, '$'), "\n") : ''
H.Match(sent, 'question text', 'the prompt text reaches the model')
H.NoMatch(sent, '{=>', 'write-target directives are stripped before sending')
H.Match(sent, 'single fenced code block',
    '{=>name=} appends the single-code-block instruction for the model')

H.Done()
