vim9script

# vim/harness.vim
# Minimal TAP-emitting assertion harness for headless vimgem tests.
#
# Every test file under vim/t/ imports this, makes assertions,
# and ends with H.Done(). Results are written as TAP to $VIMGEM_TEST_TAP
# (default: stdout via the runner's capture file) and the Vim process
# exits non-zero via :cq if any assertion failed, so `just test` and CI
# see a real failure.
#
# Why TAP: it is line-oriented, diffable, greppable, and consumable by
# prove(1)/tap parsers without a dependency. Nothing here needs a
# plugin manager or a test framework installed.

var results: list<string> = []
var count = 0
var failures = 0

export def Diag(msg: string)
    for line in split(msg, "\n")
        add(results, $'# {line}')
    endfor
enddef

export def Ok(cond: bool, name: string)
    count += 1
    if cond
        add(results, $'ok {count} - {name}')
    else
        failures += 1
        add(results, $'not ok {count} - {name}')
    endif
enddef

export def Eq(got: any, want: any, name: string)
    var pass = got == want
    Ok(pass, name)
    if !pass
        Diag($'got:      {string(got)}')
        Diag($'expected: {string(want)}')
    endif
enddef

export def Match(got: string, pat: string, name: string)
    var pass = got =~ pat
    Ok(pass, name)
    if !pass
        Diag($'got:            {string(got)}')
        Diag($'did not match:  {pat}')
    endif
enddef

export def NoMatch(got: string, pat: string, name: string)
    var pass = got !~ pat
    Ok(pass, name)
    if !pass
        Diag($'got:              {string(got)}')
        Diag($'unexpectedly hit: {pat}')
    endif
enddef

# Todo: an assertion that documents a KNOWN, still-unfixed defect. It is
# reported in TAP as a TODO, so a failure does not redden the suite -- but
# if it ever starts passing, TAP consumers flag it as unexpectedly-passing
# and you know the bug is fixed and the marker can come off.
# Use this only for documented defects, with the issue noted in `why`.
export def Todo(cond: bool, name: string, why: string)
    count += 1
    var status = cond ? 'ok' : 'not ok'
    add(results, $'{status} {count} - {name} # TODO {why}')
enddef

export def Skip(name: string, why: string)
    count += 1
    add(results, $'ok {count} - {name} # SKIP {why}')
enddef

# Assert that running `cmd` (an Ex command string) throws, and that the
# thrown message matches `pat`. Used for the error-path tests, which are
# the ones most likely to regress silently.
export def Throws(cmd: string, pat: string, name: string)
    var caught = ''
    try
        execute 'silent ' .. cmd
    catch
        caught = v:exception
    endtry
    if empty(caught)
        Ok(false, name)
        Diag($'expected a throw matching {pat}, but command succeeded')
    else
        Match(caught, pat, name)
    endif
enddef

# Run `cmd` and return everything it echoed. Some vimgem warnings (most
# notably the :AIQuery truncation notice, core.vim ~line 157) are emitted
# with :echo and never reach a buffer, so a buffer-only assertion would
# miss them entirely. Note that :echo output is transient for the user
# too -- see docs/test-plan.md, "Findings".
export def Messages(cmd: string): string
    var captured = ''
    redir => captured
    try
        # NOT :silent -- :silent suppresses the very :echo calls this is
        # meant to capture.
        execute cmd
    catch
        redir END
        return 'THREW: ' .. v:exception
    endtry
    redir END
    return captured
enddef

# Run `cmd`, returning its output buffer's lines. vimgem commands render
# into a new buffer, so this is the standard way to inspect a result.
export def BufferAfter(cmd: string): list<string>
    execute 'silent ' .. cmd
    return getline(1, '$')
enddef

# Finish: write TAP and exit. Exit status is 0 only when every assertion
# passed, so shell callers can rely on `set -e`.
export def Done()
    var plan = [$'1..{count}']
    var out = plan + results
    var tap = getenv('VIMGEM_TEST_TAP')
    if empty(tap)
        tap = '/dev/stderr'
    endif
    writefile(out, tap)
    if failures > 0
        execute 'cq 1'
    endif
    qall!
enddef
