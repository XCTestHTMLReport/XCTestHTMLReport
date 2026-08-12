# `read` under `set -e` dies before its own guard

```bash
set -e
IFS=$'\t' read -r NAME VERSION < <(some_command_producing_nothing)
if [[ -z "$NAME" ]]; then
    echo "nothing found" >&2   # unreachable
    exit 1
fi
```

`read` returns non-zero at EOF, so on empty input `set -e` terminates the script
*at the read* and the guard below never runs. The friendly error is dead code and
the failure surfaces as a bare trace.

Reproduce: `set -ex; read -r A B < <(true); echo after` — `after` never prints.

`prepareTestResults.sh` hit exactly this. It now ends that read with `|| true` so
the guard is reachable, and `Scripts/test-prepare-test-results.sh` pins the
behaviour: it stubs `xcrun` to report no iPhone simulators and asserts the exit
message is "No iPhone simulator available", not a bare `read` trace.
