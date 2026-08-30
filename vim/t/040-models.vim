vim9script
# 040-models: :AIModels listing and :AIModel switching, including the
# "put the cursor on a model line and run :AIModel" flow, which is the
# documented way to switch and is easy to break.
import '../harness.vim' as H

var base = getenv('VIMGEM_TEST_BASE_URL')
if empty(base)
    H.Skip('model tests', 'VIMGEM_TEST_BASE_URL not set')
    H.Done()
endif

silent AIProvider openai
execute 'silent AIUrl ' .. base

# --- listing ------------------------------------------------------------
silent AIModels
var listing = getline(1, '$')
var text = join(listing, "\n")
H.Match(text, base, 'listing names the server it queried')
H.NoMatch(text, '\cError:', 'listing is not an error')

# Find a real model line: indented, not a heading, not the trailing
# "Current g:openai_model" note.
var model_lnum = 0
var model_name = ''
for i in range(1, len(listing))
    var l = listing[i - 1]
    if l =~ '^\s\+\S' && l !~ '^\s*#' && l !~ 'Current g:'
        model_lnum = i
        model_name = trim(l)
        break
    endif
endfor
H.Ok(model_lnum > 0, 'listing contains at least one model line')
H.Diag('picked model line ' .. model_lnum .. ': ' .. model_name)

# --- switch by cursor position -----------------------------------------
if model_lnum > 0
    cursor(model_lnum, 1)
    silent AIModel
    silent AIInfo
    H.Match(join(getline(1, '$'), "\n"), escape(model_name, '.*[]~/\'),
        ':AIModel with the cursor on a model line switches to it')
endif

# --- switch by name -----------------------------------------------------
silent AIModel explicit-name-model
silent AIInfo
H.Match(join(getline(1, '$'), "\n"), 'explicit-name-model',
    ':AIModel <name> switches by name')

# --- cross-provider warning --------------------------------------------
# Setting a claude-looking name while openai is active should warn but
# NOT block -- local model names are unpredictable, so this is advisory.
silent! AIModel claude-sonnet-4-6
silent AIInfo
H.Match(join(getline(1, '$'), "\n"), 'claude-sonnet-4-6',
    'a cross-provider model name warns but is still accepted')

H.Done()
