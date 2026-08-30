vim9script
# 010-load: the plugin loads and defines its command surface.
# Pure offline; no server, no keys. This is the test that tells you
# whether a new .tgz unpacked correctly at all.
import '../harness.vim' as H

H.Ok(exists(':AIQuery') > 0, ':AIQuery is defined')
H.Ok(exists(':AIChat') > 0, ':AIChat is defined')
H.Ok(exists(':AIChatSend') > 0, ':AIChatSend is defined')
H.Ok(exists(':AIProvider') > 0, ':AIProvider is defined')
H.Ok(exists(':AIModels') > 0, ':AIModels is defined')
H.Ok(exists(':AIModel') > 0, ':AIModel is defined')
H.Ok(exists(':AIInfo') > 0, ':AIInfo is defined')
H.Ok(exists(':AISet') > 0, ':AISet is defined')
H.Ok(exists(':AIUrl') > 0, ':AIUrl is defined')
H.Ok(exists(':DBGSet') > 0, ':DBGSet is defined')

# Version is stamped into plugin/ai.vim at package time; a build that
# forgot to stamp it shows up here rather than in a demo video.
H.Ok(exists('g:vimgem_version') > 0, 'g:vimgem_version is set')
H.NoMatch(get(g:, 'vimgem_version', ''), '^\(NULL\)\?$', 'version is not NULL/empty')
H.Diag('version = ' .. get(g:, 'vimgem_version', '?'))

# Default mappings, unless suppressed.
if get(g:, 'ai_no_mappings', false)
    H.Skip('default mappings installed', 'g:ai_no_mappings is set')
else
    H.Ok(!empty(maparg('\c', 'n')), '\c mapped to :AIChat')
    H.Ok(!empty(maparg('\s', 'n')), '\s mapped to :AIChatSend')
endif

H.Done()
