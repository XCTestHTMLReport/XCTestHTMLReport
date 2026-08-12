# Exact per-status test counts are not assertable

`FirstSuite.testOne` appeared as both passed and failed in the same fixture
generation run. Its body is `XCTAssert(true)` plus an attachment — it cannot fail
on its own assertion. The failure comes from `setUp`, which calls
`XCUIApplication().launch()` with `continueAfterFailure = false`; under CI load
the simulator is sometimes slow and the test dies before its body runs.

This became reachable when fixtures started being regenerated on every run rather
than downloaded as fixed artifacts. Exact per-bucket counts were safe against
byte-identical fixtures; they are not against freshly generated ones.

Evidence: commit `53adfaf` passed under `Test` and failed under `Codecov` — same
code, same commands, opposite results.

**Assert what the sample sources determine** — totals, the skipped count, the
bucket-sum invariant, a floor on deliberate failures — and not the pass/fail
split, which measures the simulator rather than this project. See
`CoreTests.testResultStatusCount`.
