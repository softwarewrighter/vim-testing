# 05-chat -- a one-shot query, then a multi-turn chat.
#
# The long Sleeps around model replies are upper bounds, not read times:
# they exist so a slow model is never cut off mid-answer. Whatever is
# left over after the reply lands is collapsed by render-videos.sh, so
# the viewer gets a real read pause and no dead air either way.
# Pause vocabulary: see _common.tape.
Source "_common.tape"
Output "../out/raw/05-chat.webm"

Hide
Type "export VIMGEM_CHAT_HOME=$(mktemp -d); cd ~; clear" Enter
Show

Type "# A one-shot question. The answer opens in a scratch buffer." Enter
Sleep 7s
Type "vim" Enter
Sleep 4s
Type ":AIProvider openai" Enter
Sleep 4s
Type ":AIUrl http://localhost:11434" Enter
Sleep 4s
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 4s
Type ":AIPrompt off" Enter
Sleep 4s

Type ":AIQuery in one sentence, what is a vim9script class?" Enter
Sleep 25s
Type ":qa!" Enter
Sleep 4s

Type "clear" Enter
Type "# Now a persistent, multi-turn chat." Enter
Type "#   \c  opens one     \s  sends everything typed since '## You'" Enter
Sleep 7s

Type "vim" Enter
Sleep 4s
Type ":AIProvider openai" Enter
Sleep 4s
Type ":AIUrl http://localhost:11434" Enter
Sleep 4s
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 4s

Type "\c"
Sleep 7s
Enter
Sleep 4s

Type "GA"
Sleep 1s
Type "Write a vim9script function that reverses a list."
Escape
Sleep 4s
Type "\s"
Sleep 35s
Enter
Sleep 4s

Type "GA"
Sleep 1s
Type "Now make it operate in place."
Escape
Sleep 4s
Type "\s"
Sleep 35s
Enter
Sleep 4s

Type ":qa!" Enter
Sleep 4s
Type "clear" Enter
Type "# The whole conversation is on disk and resumable with \r" Enter
Sleep 7s
