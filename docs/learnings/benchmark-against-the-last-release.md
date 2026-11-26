# Benchmark against the last release, not just against `main`

The 4.0 reader rewrite (#443) moved every per-test `xcresulttool` read out of
the model-building queues and into the readers, where a synchronous tree walk
issues them one at a time. In 3.0.0 those reads ran inside the
`cpuCount * 2` `OperationQueue`s in `Run.swift` and `Test.swift`. The queues
survived the move, so the code still looked concurrent, but they now wrap only
the rendering of data that has already been read.

Every measurement after that compared `main` with `main`. `reader-performance.md`
recorded "parallelise the per-test reads" as unmeasured *headroom*, when it was
a regression: a 1,500-test bundle took about 160 s on `main` and 20 s on 3.0.0.
It surfaced only when #162 was reproduced against the 3.0.0 tag (2026-11-25).

**When you measure or optimise a hot path, run the last release on the same
bundle too.** A change that only matches `main` may still be slower than what
users already have. The version-compare harness (#499) builds a tag beside the
branch for this.
