# 01-install -- installing vimgem from the distribution tarball.
#
# Installs into a THROWAWAY vimdir, never the viewer's real ~/.vim, so
# the recording is reproducible and cannot damage a working setup.
Source "_common.tape"
Output "../out/raw/01-install.webm"

Require tar
Require vim

Hide
Type "cd $(mktemp -d); export DEMO=$PWD; clear" Enter
Show

Type "# vimgem ships as a .tgz -- here's the whole install." Enter
Sleep 1500ms
Type "ls ~/tools/russt/*.tgz" Enter
Sleep 2s

Type "clear" Enter
Type "# Look before you leap: the archive has NO top-level directory," Enter
Type "# so it unpacks straight into a Vim runtime dir." Enter
Sleep 1500ms
Type "tar tzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz | head -6" Enter
Sleep 3s

Type "clear" Enter
Type "# Requirements: Vim 9.1+ (it uses vim9script classes) and curl." Enter
Sleep 1200ms
Type "vim --version | head -1; command -v curl" Enter
Sleep 3s

Type "clear" Enter
Type "mkdir -p $DEMO/vimfiles" Enter
Type "tar xzf ~/tools/russt/vimgem_0.1.260827_nopack.tgz -C $DEMO/vimfiles" Enter
Sleep 1500ms
Type "find $DEMO/vimfiles -type f | head -6" Enter
Sleep 3s

Type "clear" Enter
Type "# Build the help tags so :help vimgem works..." Enter
Type "vim -es -c 'helptags $DEMO/vimfiles/doc' -c 'qa!' </dev/null; echo tagged" Enter
Sleep 2s
Type "# ...and create the log dir, which the plugin does NOT create itself." Enter
Type "mkdir -p ~/.vimgem/log" Enter
Sleep 2500ms

Type "clear" Enter
Type "# That's it. Point Vim at it and check:" Enter
Sleep 1500ms
Type "VIMINIT='set rtp^=$DEMO/vimfiles' vim" Enter
Sleep 2s
Type ":AIInfo" Enter
Sleep 10s
Sleep 4s
Type ":qa!" Enter
Sleep 1500ms
