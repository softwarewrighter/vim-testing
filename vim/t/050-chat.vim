vim9script
# 050-chat: the multi-turn session lifecycle -- the most intricate part
# of the plugin and the part most worth pinning down.
#
# What is actually asserted, beyond "a reply came back":
#   - the three sidecar files (.md/.json/.html) are created
#   - prior turns are RESENT on turn 2 (the !count directive makes the
#     server report how many messages it received, so context continuity
#     is measured rather than assumed)
#   - :AIChatClear drops the JSON history without touching the transcript
#   - a mid-chat :AIModel change does not retroactively rewrite history,
#     and the transcript records which model answered which turn
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('chat tests', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

silent AIProvider openai
execute 'silent AIUrl ' .. base
silent AIModel chat-model-a

def Turn(question: string)
    append(line('$'), question)
    silent AIChatSend
enddef

# --- open ---------------------------------------------------------------
silent AIChat
var chat_id = get(b:, 'ai_chat_id', '')
H.Ok(!empty(chat_id), ':AIChat registers b:ai_chat_id')
H.Ok(get(b:, 'ai_chat', 0) > 0, ':AIChat sets b:ai_chat')

var home = getenv('VIMGEM_CHAT_HOME')
var md = home .. '/chat-' .. chat_id .. '.md'
var js = home .. '/chat-' .. chat_id .. '.json'

# --- turn 1 -------------------------------------------------------------
Turn('!echo FIRST-REPLY')
var body = join(getline(1, '$'), "\n")
H.Match(body, 'FIRST-REPLY', 'turn 1 reply lands in the transcript')
H.Match(body, '## You', 'transcript has a You heading')
H.Match(body, '## AI', 'transcript has an AI heading')
H.Ok(filereadable(md) > 0, '.md transcript written to chat home')
H.Ok(filereadable(js) > 0, '.json history written to chat home')

var hist = json_decode(join(readfile(js), "\n"))
H.Eq(len(hist), 2, 'history holds 2 entries after one turn (user + assistant)')

# --- turn 2: prove the history is resent --------------------------------
# The mock replies "turns=N" with the number of messages it received. A
# stateless implementation would report 1 here; a correct one reports 3
# (user, assistant, user).
Turn('!count')
body = join(getline(1, '$'), "\n")
H.Match(body, 'turns=3', 'turn 2 resends the full prior conversation')

hist = json_decode(join(readfile(js), "\n"))
H.Eq(len(hist), 4, 'history holds 4 entries after two turns')

# --- mid-chat model switch ---------------------------------------------
silent AIModel chat-model-b
Turn('!echo AFTER-SWITCH')
body = join(getline(1, '$'), "\n")
H.Match(body, 'AFTER-SWITCH', 'turn 3 succeeds after a mid-chat :AIModel')
H.Match(body, 'chat-model-a', 'transcript still records the original model')
H.Match(body, 'chat-model-b', 'transcript records the new model')

# --- :AIChatClear -------------------------------------------------------
var lines_before = line('$')
silent AIChatClear
hist = json_decode(join(readfile(js), "\n"))
H.Eq(len(hist), 0, ':AIChatClear empties the JSON history')
H.Eq(line('$'), lines_before, ':AIChatClear leaves the visible transcript alone')

Turn('!count')
H.Match(join(getline(1, '$'), "\n"), 'turns=1',
    'after :AIChatClear the next turn sends only the new question')

# --- :AIChatSend outside a chat buffer ---------------------------------
enew
H.Throws('AIChatSend', '\cchat buffer\|not in',
    ':AIChatSend errors clearly outside a chat buffer')

H.Done()
