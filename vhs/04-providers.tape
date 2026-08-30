# 04-providers -- switching between LOCAL backends.
#
# The point: every local server is the SAME vimgem provider ('openai').
# Switching backend is a base-URL change and nothing else.
Source "_common.tape"
Output "../out/raw/04-providers.webm"

Hide
Type "cd ~/.vim/testing; export VIMGEM_CHAT_HOME=$(mktemp -d); clear" Enter
Show

Type "# Which local backends are reachable right now?" Enter
Sleep 1200ms
Type "just status" Enter
Sleep 20s
Sleep 4s

Type "clear" Enter
Type "# Three servers, all OpenAI-compatible, all the same provider:" Enter
Type "#   ollama         localhost:11434  -- multi-model daemon" Enter
Type "#   llama.cpp      localhost:8080   -- one model per process" Enter
Type "#   ollama remote  large12.local:11434 -- another box on the LAN" Enter
Sleep 3500ms
Type "clear" Enter
Type "vim" Enter
Sleep 1500ms

# --- backend 1: ollama -------------------------------------------------
Type ":AIProvider openai" Enter
Sleep 1000ms
Type ":AIUrl http://localhost:11434" Enter
Sleep 1000ms
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 1000ms
Type ":AIInfo" Enter
Sleep 10s
Sleep 4s
Type ":q" Enter
Sleep 1000ms

# --- backend 2: llama.cpp; ONLY the URL changes ------------------------
Type ":AIUrl http://127.0.0.1:8080" Enter
Sleep 1500ms
Type ":AIModels" Enter
Sleep 12s
Sleep 3500ms
Enter
Sleep 1000ms
Type ":q" Enter
Sleep 800ms
Type ":AIInfo" Enter
Sleep 10s
Sleep 4500ms
Type ":qa!" Enter
Sleep 1500ms
