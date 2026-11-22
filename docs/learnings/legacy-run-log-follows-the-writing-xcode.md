# The legacy run-log shape follows the Xcode that wrote the bundle

A bundle written by Xcode 27.1 stores an empty legacy array as
`{"_type":{"_name":"Array"}}` with no `_values`; one written by Xcode 26 leaves
the key out of its parent altogether. `xcresulttool get --legacy` hands back
what is stored: the 26.2 and 27.1 tools return byte-identical documents for
the same bundle. So the toolchain a report is *rendered* on says nothing about
which spelling arrives. A 27.1 bundle broke `main` running on Xcode 26.2 too.

The failure-location change in the same release goes the other way: the
`sourceLocation` object follows the `xcresulttool` *reading* the bundle (#515).

**Before calling an Xcode difference reader-side or writer-side, cross the
two:** read each bundle with each tool and compare the four outputs. Hashes
are enough to tell.

Handled in `LegacyRunLogDocument.swift`: `LegacyValues` reads a missing
`_values` as empty, and its doc comment records what that tolerance costs.
`RunLogTests.testLegacyDecoderReadsAnArrayEnvelopeWithNoValuesAsEmpty` pins it
on a crafted document, so it runs on every toolchain.
