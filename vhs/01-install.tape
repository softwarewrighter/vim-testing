# 01-install -- installing vimgem from the distribution tarball.
#
# Installs into a THROWAWAY vimdir, never the viewer's real ~/.vim.
# Pause vocabulary: see _common.tape.
Source "_common.tape"
Output "../out/raw/01-install.webm"

Require tar
Require vim

Hide
Type "cd $(mktemp -d); export DEMO=$PWD; clear" Enter
Show

Type "# vimgem ships as a .tgz -- here is the whole install." Enter
Sleep 7s
Type "ls ~/tools/russt/*.tgz" Enter
Sleep 7s

Type "clear" Enter
Type "# The archive has NO top-level directory: it unpacks straight" Enter
Type "# into a Vim runtime dir. Always look before you extract." Enter
Sleep 7s
Type "tar tzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz | head -6" Enter
Sleep 11s

Type "clear" Enter
Type "# Requirements: Vim 9.1+ (it uses vim9script classes) and curl." Enter
Sleep 7s
Type "vim --version | head -1; command -v curl" Enter
Sleep 11s

Type "clear" Enter
Type "mkdir -p $DEMO/vimfiles" Enter
Type "tar xzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz -C $DEMO/vimfiles" Enter
Sleep 7s
Type "find $DEMO/vimfiles -type f | head -6" Enter
Sleep 11s

Type "clear" Enter
Type "# Build the help tags so :help vimgem works..." Enter
Sleep 7s
Type "vim -es -c 'helptags $DEMO/vimfiles/doc' -c 'qa!' </dev/null; echo tagged" Enter
Sleep 7s
Type "# ...and make the log dir, which the plugin does NOT create itself." Enter
Sleep 7s
Type "mkdir -p ~/.vimgem/log" Enter
Sleep 7s

Type "clear" Enter
Type "# That is the whole install. Point Vim at it and check:" Enter
Sleep 7s
Type "VIMINIT='set rtp^=$DEMO/vimfiles' vim" Enter
Sleep 4s
Type ":AIInfo" Enter
Sleep 15s
Type ":qa!" Enter
Sleep 4s
