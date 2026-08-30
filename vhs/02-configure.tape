# 02-configure -- configuring vimgem for a local model server.
Source "_common.tape"
Output "../out/raw/02-configure.webm"

Hide
Type "export VIMGEM_CHAT_HOME=$(mktemp -d); cd ~; clear" Enter
Show

Type "# vimgem has three providers: gemini, claude, and openai." Enter
Sleep 1200ms
Type "# 'openai' means ANY OpenAI-compatible server -- so ollama," Enter
Type "# llama.cpp and vLLM are all the 'openai' provider." Enter
Sleep 2500ms

Type "clear" Enter
Type "vim" Enter
Sleep 1500ms

Type ":AIInfo" Enter
Sleep 10s
Sleep 3500ms
Type ":q" Enter
Sleep 800ms

# Point it at a local server. No API key needed.
Type ":AIProvider openai" Enter
Sleep 1200ms
Type ":AIUrl http://localhost:11434" Enter
Sleep 1200ms
Type ":AIModel qwen2.5-coder:7b" Enter
Sleep 1200ms
Type ":AIInfo" Enter
Sleep 10s
Sleep 4s
Type ":q" Enter
Sleep 800ms

# :AISet lists every config key. Values are LITERAL -- never quote them.
Type ":AISet" Enter
Sleep 10s
Sleep 4s
Type ":qa!" Enter
Sleep 1500ms
