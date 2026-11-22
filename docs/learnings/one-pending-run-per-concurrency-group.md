# GitHub keeps only one pending run per concurrency group

A workflow `concurrency:` group holds at most one running and one *pending*
run. When another run queues, the older pending one is cancelled, and that
happens even with `cancel-in-progress: false`: the setting protects the
running job, not the queue.

So a group keyed on the ref (`${{ github.workflow }}-${{ github.ref }}`) loses
runs on `main` when merges land close together, and the commit whose run was
dropped never gets a verdict. This came out of the review of #514.

**Key a cancelling group on the pull request, and give every other run a
group of its own.** Since #514, `ci.yml`, `lint.yml`, `test.yml` and
`visual.yml` all do:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: true
```

A new push then cancels that pull request's earlier run. A push to `main` or a
manual dispatch is keyed on its run id, shares a group with nothing, and so is
never cancelled and never made to wait.
