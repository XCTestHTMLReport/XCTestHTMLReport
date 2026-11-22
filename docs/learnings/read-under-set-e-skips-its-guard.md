# `read` under `set -e` dies before its own guard

```bash
set -e
IFS=$'\t' read -r NAME VERSION < <(some_command_producing_nothing)
if [[ -z "$NAME" ]]; then
    echo "nothing found" >&2   # unreachable
    exit 1
fi
```

`read` returns non-zero at end of input, so on empty input `set -e` ends the
script *at the read*. The friendly error below it is dead code and the failure
surfaces as a bare trace.

Reproduce: `bash -c 'set -e; read -r A B < <(true); echo after'` prints nothing.

`prepareTestResults.sh` hit exactly this when no iPhone simulator was
available. It now ends that `read` with `|| true`, with a comment saying why,
so the "No iPhone simulator available" guard is reachable.
