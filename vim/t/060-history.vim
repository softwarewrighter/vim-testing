vim9script
# 060-history: :AIChatHistory / :AIChatResume / :AIChatDelete.
# Session management is filesystem state, so this test creates its own
# sessions and then drives the listing exactly as a user would: cursor on
# a line, run the command.
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('history tests', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

var home = getenv('VIMGEM_CHAT_HOME')
silent AIProvider openai
execute 'silent AIUrl ' .. base
silent AIModel hist-model

# --- create two sessions ------------------------------------------------
silent AIChat
var id1 = get(b:, 'ai_chat_id', '')
append(line('$'), '!echo SESSION-ONE')
silent AIChatSend

# Session ids are strftime('%Y%m%d-%H%M%S') with no uniqueness check
# (buffer.vim CreateChat), so two :AIChat calls inside one second collide
# and the second silently resets the first one's history. See
# 090-known-issues.vim for the filed reproduction; sleep past the
# boundary here so the rest of this file tests what it means to test.
sleep 1100m

silent AIChat
var id2 = get(b:, 'ai_chat_id', '')
append(line('$'), '!echo SESSION-TWO')
silent AIChatSend

H.Ok(id1 != id2, 'two :AIChat calls a second apart get distinct ids')

# --- listing ------------------------------------------------------------
silent AIChatHistory
var listing = join(getline(1, '$'), "\n")
H.Match(listing, id1, 'history lists the first session')
H.Match(listing, id2, 'history lists the second session')
H.Match(listing, 'hist-model', 'history shows the model used')

# --- resume the older session by cursor --------------------------------
var target = 0
for i in range(1, line('$'))
    if getline(i) =~ id1
        target = i
        break
    endif
endfor
H.Ok(target > 0, 'found the first session line in the listing')

if target > 0
    cursor(target, 1)
    silent AIChatResume
    H.Eq(get(b:, 'ai_chat_id', ''), id1, ':AIChatResume opens the session under the cursor')
    H.Match(join(getline(1, '$'), "\n"), 'SESSION-ONE',
        'resumed session still holds its earlier turn')

    # A resumed session must keep its history: turns=3 means the two
    # existing entries were reloaded from the .json, not lost.
    append(line('$'), '!count')
    silent AIChatSend
    H.Match(join(getline(1, '$'), "\n"), 'turns=3',
        'resumed session resends the history it was saved with')
endif

# --- delete by cursor ---------------------------------------------------
silent AIChatHistory
target = 0
for i in range(1, line('$'))
    if getline(i) =~ id2
        target = i
        break
    endif
endfor
if target > 0
    cursor(target, 1)
    silent AIChatDelete
    H.Ok(filereadable(home .. '/chat-' .. id2 .. '.md') == 0,
        ':AIChatDelete removes the .md transcript')
    H.Ok(filereadable(home .. '/chat-' .. id2 .. '.json') == 0,
        ':AIChatDelete removes the .json history')
    H.NoMatch(join(getline(1, '$'), "\n"), id2,
        ':AIChatDelete refreshes the listing in place')
    H.Match(join(getline(1, '$'), "\n"), id1,
        ':AIChatDelete leaves the other session alone')
endif

H.Done()
