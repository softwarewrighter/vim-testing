# 05-chat -- a one-shot query, then a multi-turn chat.
#
# Every model response is waited on with Wait+Screen, not slept through,
# so the recording moves on the instant the reply lands regardless of how
# fast or slow the model is. Retuning for a different model should not be
# necessary; only the @timeouts are a ceiling.
Source "_common.tape"
Output "../out/raw/05-chat.webm"

Hide
Type "export VIMGEM_CHAT_HOME=$(mktemp -d); cd ~; clear" Enter
Show

Type "# A one-shot question. The answer opens in a scratch buffer." Enter
Sleep 1800ms
Type "vim" Enter
Sleep 1500ms
Type ":AIProvider openai" Enter
Sleep 900ms
Type ":AIUrl http://localhost:11434" Enter
Sleep 900ms
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 900ms
Type ":AIPrompt off" Enter
Sleep 900ms

Type ":AIQuery in one sentence, what is a vim9script class?" Enter
Sleep 25s
Sleep 4500ms
Type ":qa!" Enter
Sleep 1200ms

Type "clear" Enter
Type "# Now a persistent, multi-turn chat." Enter
Type "#   \c  opens one     \s  sends everything typed since '## You'" Enter
Sleep 3s

Type "vim" Enter
Sleep 1500ms
Type ":AIProvider openai" Enter
Sleep 900ms
Type ":AIUrl http://localhost:11434" Enter
Sleep 900ms
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 900ms

Type "\c"
Sleep 15s
Sleep 1800ms
Enter
Sleep 800ms

Type "GA"
Sleep 400ms
Type "Write a vim9script function that reverses a list."
Escape
Sleep 1200ms
Type "\s"
Sleep 35s
Sleep 4s
Enter
Sleep 1000ms

Type "GA"
Sleep 400ms
Type "Now make it operate in place."
Escape
Sleep 1200ms
Type "\s"
Sleep 35s
Sleep 4500ms
Enter
Sleep 1200ms

Type ":qa!" Enter
Sleep 1200ms
Type "clear" Enter
Type "# The whole conversation is on disk and resumable with \r" Enter
Sleep 2500ms
