# 04-providers -- switching between local and remote backends.
#
# The point: every one of these servers is the SAME vimgem provider
# ('openai'). Switching backend is a base-URL change and nothing else.
# Pause vocabulary: see _common.tape.
Source "_common.tape"
Output "../out/raw/04-providers.webm"

Hide
Type "cd ..; export VIMGEM_CHAT_HOME=$(mktemp -d); clear" Enter
Show

Type "# Which backends are reachable right now?" Enter
Sleep 7s
Type "just status" Enter
Sleep 15s

Type "clear" Enter
Type "# Three servers, all OpenAI-compatible, all the same provider:" Enter
Type "#   ollama         localhost:11434     -- multi-model daemon" Enter
Type "#   llama.cpp      localhost:8080      -- one model per process" Enter
Type "#   ollama remote  large12.local:11434 -- another box on the LAN" Enter
Sleep 11s
Type "clear" Enter
Type "vim" Enter
Sleep 4s

# --- backend 1: ollama -------------------------------------------------
Type ":AIProvider openai" Enter
Sleep 4s
Type ":AIUrl http://localhost:11434" Enter
Sleep 4s
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 4s
Type ":AIInfo" Enter
Sleep 15s
Type ":q" Enter
Sleep 4s

# --- backend 2: llama.cpp; ONLY the URL changes ------------------------
Type ":AIUrl http://127.0.0.1:8080" Enter
Sleep 4s
Type ":AIModels" Enter
Sleep 15s
Enter
Sleep 4s
Type ":q" Enter
Sleep 4s
Type ":AIInfo" Enter
Sleep 15s
Type ":q" Enter
Sleep 4s

# --- backend 3: ollama on another machine; still only the URL ----------
Type ":AIUrl http://large12.local:11434" Enter
Sleep 4s
Type ":AIModel qwen2.5-coder:14b" Enter
Sleep 4s
Type ":AIInfo" Enter
Sleep 15s
Type ":qa!" Enter
Sleep 4s
