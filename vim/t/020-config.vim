vim9script
# 020-config: :AISet / :AIProvider / :AIUrl round-trips and validation.
# Offline. These are the commands a user touches during setup, so a
# regression here is a setup-day regression.
import '../harness.vim' as H

def Info(): string
    silent AIInfo
    return join(getline(1, '$'), "\n")
enddef

# --- provider switching -------------------------------------------------
silent AIProvider openai
H.Match(Info(), 'Current Provider: openai', ':AIProvider openai takes effect')
silent AIProvider gemini
H.Match(Info(), 'Current Provider: gemini', ':AIProvider gemini takes effect')
silent AIProvider claude
H.Match(Info(), 'Current Provider: claude', ':AIProvider claude takes effect')

H.Throws('AIProvider bogus', 'bogus\|Invalid\|valid', ':AIProvider rejects an unknown name')

# --- :AISet round-trip --------------------------------------------------
# Values are literal text, NOT evaluated like :let -- the docs warn that
# quoting produces a value with the quotes embedded. Assert that the
# documented (unquoted) form is what survives.
silent AIProvider openai
silent AISet openai_model test-model-xyz
H.Match(Info(), 'test-model-xyz', ':AISet openai_model round-trips')

silent AISet gemini_api_version v1beta
silent AIProvider gemini
H.Match(Info(), 'API Version: v1beta', ':AISet gemini_api_version round-trips')

# --- :AIUrl is openai-only ---------------------------------------------
H.Throws('AIUrl http://example.com', 'openai\|provider',
    ':AIUrl refuses to run while a non-openai provider is active')

silent AIProvider openai
silent AIUrl http://127.0.0.1:9099
H.Match(Info(), 'http://127\.0\.0\.1:9099', ':AIUrl sets the base URL')

# --- show_prompt toggle -------------------------------------------------
silent AIPrompt on
H.Match(Info(), 'Show Prompt: Yes', ':AIPrompt on')
silent AIPrompt off
H.Match(Info(), 'Show Prompt: No', ':AIPrompt off')
silent AIPrompt
H.Match(Info(), 'Show Prompt: Yes', ':AIPrompt with no arg toggles')

H.Done()
