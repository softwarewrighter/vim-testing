vim9script
# 080-wire: what vimgem actually puts on the wire.
#
# Asserted here rather than in the shell because these are Vim-side
# decisions; the shell half (scripts/assert-wire.sh) then reads the
# mock's request log to confirm the SHAPE of what was sent. Split this
# way, a change in either the request payload or the log format fails
# loudly instead of quietly passing. run-tests.sh runs both.
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('wire tests', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

silent AIProvider openai
execute 'silent AIUrl ' .. base
silent AIPrompt off

# --- empty model means the field is omitted entirely --------------------
# This is deliberate (see openai.vim ExecuteChatRequest): mlx_lm.server
# and most single-model local servers want no "model" key at all, and
# some servers try to FETCH a model whose name they do not recognise.
# assert-wire.sh confirms model_present == false for this request.
#
# NOTE: openai_model is empty here because that is its DEFAULT
# (PROVIDER_MODEL_DEFAULTS.openai == ''), not because anything cleared
# it. There is no way to clear a config value back to empty at runtime --
# `:AISet <key>` with no value only REPORTS it. See Issue 4 in
# docs/test-plan.md. This test must therefore run before anything sets a
# model, which is why the ordering below matters.
H.Eq(get(g:, 'openai_model', ''), '', 'precondition: no model configured yet')
silent AIQuery !echo WIRE-NO-MODEL
H.Match(join(getline(1, '$'), "\n"), 'WIRE-NO-MODEL', 'request with no model field succeeds')

# --- a set model is sent ------------------------------------------------
silent AIModel wire-test-model
silent AIQuery !echo WIRE-WITH-MODEL
H.Match(join(getline(1, '$'), "\n"), 'WIRE-WITH-MODEL', 'request with a model field succeeds')

# --- api key becomes an Authorization header ---------------------------
silent AISet openai_api_key wire-secret-token
silent AIQuery !echo WIRE-WITH-KEY
H.Match(join(getline(1, '$'), "\n"), 'WIRE-WITH-KEY', 'request with an API key succeeds')
silent AISet openai_api_key

H.Done()
