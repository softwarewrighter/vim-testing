#!/usr/bin/env bash
# install.sh -- install a vimgem .tgz and run the test suite against it.
#
# This repo holds ONLY the testing work. The plugin itself ships as a
# tarball from its author and is deliberately not vendored here, so this
# script is how you point the tests at a build.
#
#   ./install.sh subject/vimgem_0.1.260827_nopack.tgz
#   ./install.sh <tgz> --mode home        # install to a clean ~/.vim
#   ./install.sh <tgz> --mode home --keep # ...and leave it installed
#   ./install.sh <tgz> --no-test          # unpack only
#
# Two modes
# ---------
#   sandbox (default, and safe)
#       Unpacks to subject/vimfiles-<version>/ and runs the suite with
#       --clean plus that directory prepended to 'runtimepath'. Your
#       ~/.vim is never touched, and two builds can be A/B'd side by side.
#
#   home
#       Some things can only be verified in the real location: that the
#       tarball unpacks correctly into ~/.vim, that :help tags resolve,
#       that no leftover file from a previous release interferes. This
#       mode moves any existing ~/.vim aside, installs the tarball into a
#       clean ~/.vim, tests it, and then RESTORES your original unless
#       --keep is given.
#
# Safety in home mode
# -------------------
#   * refuses to run if a backup directory already exists, rather than
#     overwriting a previous backup
#   * an EXIT trap restores ~/.vim even if the tests fail, the script
#     errors, or you interrupt it
#   * prints exactly what it will move, and asks first unless --yes
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

MODE=sandbox
KEEP=0
RUN_TESTS=1
ASSUME_YES=0
BACKEND=mock
TGZ=""

die()  { printf '\033[31mERROR\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[2m==>\033[0m %s\n' "$*"; }
pass() { printf '\033[32mPASS\033[0m %s\n' "$*"; }
warn() { printf '\033[33mWARN\033[0m %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)    MODE="$2"; shift 2 ;;
        --backend) BACKEND="$2"; shift 2 ;;
        --keep)    KEEP=1; shift ;;
        --no-test) RUN_TESTS=0; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        -*)        die "unknown option: $1" ;;
        *)         TGZ="$1"; shift ;;
    esac
done

[ -n "$TGZ" ] || die "usage: ./install.sh <path-to-vimgem.tgz> [--mode sandbox|home]"
[ -f "$TGZ" ] || die "no such file: $TGZ"
TGZ="$(cd "$(dirname "$TGZ")" && pwd)/$(basename "$TGZ")"

# --- inspect before extracting ------------------------------------------
# The tarball has no top-level directory: its paths start at plugin/,
# autoload/ and doc/, so it overwrites same-named files wherever it is
# unpacked. Verify that shape before trusting it anywhere near $HOME.
info "inspecting $(basename "$TGZ")"
listing="$(tar tzf "$TGZ")" || die "cannot read $TGZ as a gzip tarball"
if printf '%s\n' "$listing" | grep -qE '^/|(^|/)\.\.(/|$)'; then
    die "refusing: tarball contains absolute or parent-relative paths"
fi
printf '%s\n' "$listing" | grep -qE '^plugin/ai\.vim$' \
    || die "refusing: this does not look like a vimgem tarball (no plugin/ai.vim)"

VERSION="$(printf '%s\n' "$(basename "$TGZ")" | sed -n 's/^vimgem_\([0-9.]*\)_.*$/\1/p')"
VERSION="${VERSION:-unknown}"
info "vimgem version $VERSION, $(printf '%s\n' "$listing" | grep -c . ) entries"

restore_home() {
    # Called from the EXIT trap in home mode.
    [ -n "${BACKUP_DIR:-}" ] || return 0
    [ -d "$BACKUP_DIR" ] || return 0
    if [ "$KEEP" -eq 1 ]; then
        warn "--keep given: leaving the new install at ~/.vim"
        warn "your previous ~/.vim is preserved at $BACKUP_DIR"
        return 0
    fi
    info "restoring your original ~/.vim"
    rm -rf "$HOME/.vim"
    mv "$BACKUP_DIR" "$HOME/.vim"
    pass "~/.vim restored"
}

case "$MODE" in
    sandbox)
        TARGET="$REPO_DIR/subject/vimfiles-$VERSION"
        info "sandbox install -> $TARGET"
        rm -rf "$TARGET"
        mkdir -p "$TARGET"
        tar xzf "$TGZ" -C "$TARGET"
        vim -es -c "helptags $TARGET/doc" -c 'qa!' </dev/null 2>/dev/null
        pass "unpacked ($(find "$TARGET" -type f | wc -l | tr -d ' ') files)"
        export VIMGEM_TEST_RTP="$TARGET"
        ;;
    home)
        BACKUP_DIR="$HOME/.bak-vim"
        if [ -d "$HOME/.vim" ]; then
            [ -e "$BACKUP_DIR" ] && die "$BACKUP_DIR already exists -- move or remove it first; refusing to overwrite an existing backup"
            if [ "$ASSUME_YES" -eq 0 ]; then
                echo
                echo "About to move  $HOME/.vim  ->  $BACKUP_DIR"
                echo "install $(basename "$TGZ") into a clean ~/.vim, run the tests,"
                if [ "$KEEP" -eq 1 ]; then
                    echo "and LEAVE the new install in place (--keep)."
                else
                    echo "then restore your original ~/.vim."
                fi
                printf 'Proceed? [y/N] '
                read -r reply </dev/tty || reply=n
                case "$reply" in y|Y|yes|YES) ;; *) die "aborted" ;; esac
            fi
            trap restore_home EXIT INT TERM
            mv "$HOME/.vim" "$BACKUP_DIR"
            info "moved ~/.vim -> $BACKUP_DIR"
        else
            info "no existing ~/.vim to back up"
        fi
        mkdir -p "$HOME/.vim"
        tar xzf "$TGZ" -C "$HOME/.vim"
        vim -es -c "helptags $HOME/.vim/doc" -c 'qa!' </dev/null 2>/dev/null
        mkdir -p "$HOME/.vimgem/log"
        pass "installed into a clean ~/.vim"
        # Tests run against the default runtimepath, i.e. the real ~/.vim.
        unset VIMGEM_TEST_RTP
        ;;
    *) die "unknown mode: $MODE (sandbox|home)" ;;
esac

if [ "$RUN_TESTS" -eq 0 ]; then
    info "--no-test given; stopping here"
    exit 0
fi

info "running the suite (backend: $BACKEND)"
if [ -n "${VIMGEM_TEST_RTP:-}" ]; then
    ./scripts/run-tests.sh --backend "$BACKEND" --sandbox "$VIMGEM_TEST_RTP"
else
    ./scripts/run-tests.sh --backend "$BACKEND"
fi
rc=$?

[ "$rc" -eq 0 ] && pass "vimgem $VERSION passed" || warn "vimgem $VERSION FAILED (exit $rc)"
exit $rc
