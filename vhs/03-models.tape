# 03-models -- listing models and switching between them.
# Pause vocabulary: see _common.tape.
Source "_common.tape"
Output "../out/raw/03-models.webm"

Hide
Type "cd ..; export VIMGEM_CHAT_HOME=$(mktemp -d); clear" Enter
Show

Type "# From the shell: what does every live backend have?" Enter
Sleep 7s
Type "just models" Enter
Sleep 15s

Type "clear" Enter
Type "# large12.local runs ollama too, with a much bigger library." Enter
Sleep 7s
Type "just models remote" Enter
Sleep 15s

Type "clear" Enter
Type "# From inside Vim, :AIModels asks the server what it can serve." Enter
Sleep 7s
Type "vim" Enter
Sleep 4s

Type ":AIProvider openai" Enter
Sleep 4s
Type ":AIUrl http://localhost:11434" Enter
Sleep 4s
Type ":AIModels" Enter
Sleep 15s
Enter
Sleep 4s

# Put the cursor on a model line, then select it.
Down Down Down Down Down Down
Sleep 7s
Type ":AIModel" Enter
Sleep 11s
Enter
Sleep 4s

# Close the listing so :AIInfo gets the full window -- the payoff shot.
Type ":q" Enter
Sleep 4s
Type ":AIInfo" Enter
Sleep 15s
Type ":q" Enter
Sleep 4s

# Same command, remote server -- only the URL changed.
Type ":AIUrl http://large12.local:11434" Enter
Sleep 4s
Type ":AIModels" Enter
Sleep 15s
Enter
Sleep 11s
Type ":qa!" Enter
Sleep 4s
