# 02-configure -- configuring vimgem for a local model server.
# Pause vocabulary: see _common.tape.
Source "_common.tape"
Output "../out/raw/02-configure.webm"

Hide
Type "export VIMGEM_CHAT_HOME=$(mktemp -d); cd ~; clear" Enter
Show

Type "# vimgem has three providers: gemini, claude, and openai." Enter
Sleep 7s
Type "# 'openai' means ANY OpenAI-compatible server -- so ollama," Enter
Type "# llama.cpp and vLLM are all the 'openai' provider." Enter
Sleep 7s

Type "clear" Enter
Type "vim" Enter
Sleep 4s

Type ":AIInfo" Enter
Sleep 15s
Type ":q" Enter
Sleep 4s

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

Type ":AISet" Enter
Sleep 15s
Type ":qa!" Enter
Sleep 4s
