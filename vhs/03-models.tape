# 03-models -- listing models and switching between them.
Source "_common.tape"
Output "../out/raw/03-models.webm"

Hide
Type "cd ~/.vim/testing; export VIMGEM_CHAT_HOME=$(mktemp -d); clear" Enter
Show

Type "# From the shell: what does every live backend have?" Enter
Sleep 1200ms
Type "just models" Enter
Sleep 20s
Sleep 3500ms

Type "clear" Enter
Type "# large12.local runs ollama too, with a much bigger library." Enter
Sleep 1200ms
Type "just models remote" Enter
Sleep 12s

Type "clear" Enter
Type "# From inside Vim, :AIModels asks the server what it can serve." Enter
Sleep 1800ms
Type "vim" Enter
Sleep 1500ms

Type ":AIProvider openai" Enter
Sleep 1000ms
Type ":AIUrl http://localhost:11434" Enter
Sleep 1000ms
Type ":AIModels" Enter
Sleep 12s
Sleep 3s
Enter
Sleep 1200ms

# Put the cursor on a model line, then select it.
Down Down Down Down Down Down
Sleep 1800ms
Type ":AIModel" Enter
Sleep 10s
Sleep 2s
Enter
Sleep 1000ms

# Close the listing so :AIInfo gets the full window -- the payoff shot.
Type ":q" Enter
Sleep 800ms
Type ":AIInfo" Enter
Sleep 10s
Sleep 4500ms
Type ":q" Enter
Sleep 800ms

# Same command, remote server -- only the URL changed.
Type ":AIUrl http://large12.local:11434" Enter
Sleep 1200ms
Type ":AIModels" Enter
Sleep 12s
Enter
Sleep 4s
Type ":qa!" Enter
Sleep 1500ms
