vim9script

# vim/testrc.vim
# The vimrc used for every headless test run. Deliberately minimal: the
# point is to test vimgem, not the user's editing setup.
#
# Two modes, selected by $VIMGEM_TEST_RTP:
#   unset          - test the installed plugin at ~/.vim (the normal case)
#   <dir>          - prepend <dir> to 'runtimepath' and test that copy
#                    instead. Used with `--clean` to test a freshly
#                    unpacked .tgz in a sandbox without touching ~/.vim,
#                    which is what makes install tests and A/B-ing two
#                    releases possible.

set nocompatible
set nomore                  # never page output; a pager prompt in -es mode
                            # blocks forever on stdin
set noswapfile
set shortmess+=at
set viminfo=

var rtp = getenv('VIMGEM_TEST_RTP')
if !empty(rtp)
    &runtimepath = rtp .. ',' .. &runtimepath
endif

filetype plugin indent on
syntax on

# Tests must never write into the user's real ~/.vimgem/ai-chat. The
# runner always exports VIMGEM_CHAT_HOME into a per-run temp dir; refuse
# to start if that did not happen, rather than silently polluting it.
var chat_home = getenv('VIMGEM_CHAT_HOME')
if empty(chat_home) || chat_home =~ '\V\^' .. escape(expand('~/.vimgem/ai-chat'), '\') .. '\$'
    echoerr 'testrc: VIMGEM_CHAT_HOME must be set to a scratch dir before running tests'
    cquit 2
endif
