# Exact pass/fail splits are not assertable on generated fixtures

`FirstSuite.testOne`, whose body is `XCTAssert(true)`, once appeared as both
passed and failed across fixture runs: `setUp` launched the app with
`continueAfterFailure = false`, and a slow simulator killed the test before
its body ran. Commit `53adfaf` passed under `Test` and failed under `Codecov`
with the same code and commands.

#423 removed those launches from the sample UI suites, since they were pure
flake risk (the comment on `FirstSuite.testAttachScreenshot` says not to add
one back). The rule stands anyway: fixtures are regenerated on every run, so a
run still depends on the simulator behaving, and an exact split would measure
that rather than this project.

**Assert what the sample sources determine**: totals, the skipped count,
expected failures, relationships between buckets. Not the pass/fail split.
`CoreTests.testResultStatusCount` (in `FilterCountTests.swift`) is the model.

Fixture-level breakage, a bundle that generated partially or lost its hosted
tests, is caught earlier by `scripts/verify_fixtures.sh`, which checks each
bundle's expected test count.
