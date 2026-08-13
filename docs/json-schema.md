# The `--json` report schema

This document is the wire contract for the file `xchtmlreport --json` writes
(`report.json`). It is versioned by the top-level `schemaVersion` field and
changes only by the policy at the end of this document. The Swift types that
produce it (`JsonReport.swift`) implement this contract; the internal
`ParsedResult` model is **not** the contract, and renaming a Swift property
must never change this output — that is why the encoder names every key
explicitly instead of synthesizing them from the model.

Introduced in 4.0. Before 4.0, `--json` dumped the legacy `xcresulttool`
object graph verbatim (every scalar wrapped in `{"_value": ...}`, keys named
by Apple's internal types). That graph is Apple's internal shape and
disappears with the legacy commands, so the output is now our own schema,
emitted identically by both result readers. See the 4.0 release notes for the
migration rationale.

## Document shape

One invocation writes one JSON document, whatever the number of `.xcresult`
bundles passed. The document is a single object:

| Key | Type | Meaning |
| --- | --- | --- |
| `schemaVersion` | string | The version of this contract, semver. `"1.0.0"` as of this document. |
| `runs` | array of Run | Every run from every bundle, in bundle-argument order, then in the bundle's own action/device order. |

The document is pretty-printed with lexicographically sorted keys, so two
reports over the same bundle with the same reader are byte-comparable.

### The null rule — one rule, uniform

**Every key named in this document is present in every emission.** A value
the reader cannot supply is `null`, never omitted. Arrays are never `null`:
a collection with no elements is `[]`. There are no optional keys, so
consumers never need existence checks — only null checks, and only on the
fields whose type below says "or null".

### Run

| Key | Type | Meaning |
| --- | --- | --- |
| `destination` | Destination | The device the run executed on. |
| `testables` | array of Testable | One entry per test target, in document order. |

### Destination

| Key | Type | Meaning |
| --- | --- | --- |
| `displayName` | string | E.g. `"iPhone 16 Pro"`. |
| `deviceIdentifier` | string | The device UDID. |
| `modelName` | string | E.g. `"iPhone 16 Pro"`. |
| `operatingSystemVersion` | string | E.g. `"26.2"`. |

### Testable

| Key | Type | Meaning |
| --- | --- | --- |
| `targetName` | string | The test target, e.g. `"SampleAppUnitTests"`. |
| `groups` | array of Node | The target's top-level nodes, in document order. |

### Node — group or test case

The test tree is recursive: a group's `children` holds further groups and
test cases, discriminated by `kind`. Consumers must switch on `kind`, not on
the presence of other keys.

`kind: "group"` — a suite, plan, or (legacy only) wrapper level:

| Key | Type | Meaning |
| --- | --- | --- |
| `kind` | string | `"group"`. |
| `name` | string | Display name, e.g. `"FirstSuite"`. |
| `identifier` | string | The backend's identifier for the group. |
| `duration` | number | Seconds. `0` where the format carries none (see the cross-backend table). |
| `children` | array of Node | Sub-groups and test cases, in document order. |

`kind: "testCase"` — a test method:

| Key | Type | Meaning |
| --- | --- | --- |
| `kind` | string | `"testCase"`. |
| `name` | string | The function-form name, e.g. `"testTwo()"`. |
| `identifier` | string | Suite-qualified, e.g. `"FirstSuite/testTwo()"`. Stable across backends; use this as the diff key. |
| `arguments` | array of string | Swift Testing `@Test(arguments:)` values, one per argument set, in document order. `[]` for non-parameterized tests and always `[]` on the legacy reader (see class 2 below). |
| `iterations` | array of Iteration | One per repetition; a non-repeated test has exactly one. Ascending iteration number. |

### Iteration

| Key | Type | Meaning |
| --- | --- | --- |
| `iterationNumber` | integer or null | 1-based repetition number. `null` when the backend reports no repetition information (every non-repeated test). |
| `status` | string | See "Status encoding". |
| `duration` | number | Seconds. |
| `activities` | array of Activity | The iteration's timeline, top level only here; nesting is inside each activity. See "Ordering". |

### Activity

| Key | Type | Meaning |
| --- | --- | --- |
| `title` | string | The row's text, e.g. `"Start Activity"` or the failure message. |
| `isFailure` | boolean | `true` when this row *is* an assertion failure, appended failure message, or skip notice — not when it merely contains one. |
| `start` | string or null | ISO-8601 UTC with milliseconds, e.g. `"2026-08-12T21:22:33.123Z"`. `null` for unpositioned annotation rows (appended failure messages, skip notices). |
| `attachments` | array of Attachment | In document order. |
| `subActivities` | array of Activity | Nested rows, in document order. |

### Attachment

| Key | Type | Meaning |
| --- | --- | --- |
| `name` | string or null | The user-supplied `XCTAttachment` name. `null` on the modern reader, which has no source for it (class 1 below). |
| `filename` | string or null | The content-addressed exported file name, `<payloadId>.<ext>` — identical across backends, unique per payload. `null` for an attachment with no payload. |
| `filenameExtension` | string or null | Lowercased, no leading dot, e.g. `"png"`. `null` when neither the filename nor the type carries one. |

## Status encoding

`status` is one of exactly five strings — our neutral vocabulary, in neither
backend's spelling, never ordinals:

| Value | Meaning |
| --- | --- |
| `"passed"` | Legacy `Success`, modern `Passed`. |
| `"failed"` | Legacy `Failure`, modern `Failed`. |
| `"skipped"` | Both spell it `Skipped`. |
| `"expectedFailure"` | An `XCTExpectFailure` that failed as expected. |
| `"unknown"` | Anything the reader did not recognise. |

A test with several iterations carries one status per iteration; the
"mixed" state the HTML report shows is a rendering of those, not a wire
value — derive it by folding `iterations[].status`.

## Units and formats

- **Durations** are seconds, as a JSON number. `0` where the format carries
  no value (never `null`, because "no duration" and "took no time" render
  identically everywhere this value is consumed — see the cross-backend
  table for where that happens).
- **Timestamps** are ISO-8601 in UTC with exactly millisecond precision and
  a trailing `Z`: `2026-08-12T21:22:33.123Z`. Both underlying formats stamp
  at millisecond granularity, so no precision is invented or lost.

## Ordering guarantees

Consumers may diff two reports line by line; every array order is
deterministic:

- `runs`: bundle argument order, then the bundle's own action/device order.
- `testables`, `groups`, `children`, `attachments`, `subActivities`,
  `arguments`: the backend's document order, which is stable for a given
  bundle and reader.
- `iterations`: ascending `iterationNumber`, source order on ties.
- `activities`: total order — ascending `start` with `null` last, activities
  before failure rows on equal `start`, source order last. Both readers place
  failure rows through one shared function, so this order is identical
  across backends.
- Object keys are lexicographically sorted.

## Identical across backends — and the two permitted exceptions

Both readers emit the same keys, nesting, enum vocabulary, and
`schemaVersion`: a group carries the same keys on both backends, a test case
carries the same keys on both backends, at whatever depth a node sits. (The
wrapper levels below mean legacy alone places group nodes at nested
positions — deeper documents, never different keys.) Value differences fall
into exactly two classes;
anything outside them is a reader bug, not a permitted variance.

**Class 1 — the four declared render-level losses** (the same allow-list the
HTML differential holds both backends to):

| Rule | Where it shows in this schema |
| --- | --- |
| `attachmentDisplayNames` | `attachment.name` is a string on legacy, `null` on modern. |
| `failureTitlePrefix` | Failure-row `title` is `<issueType> at <file>:<line>:<message>` on legacy, the pre-joined `<file>:<line>: <message>` on modern. |
| `wrapperGroups` | Legacy nests two extra group levels (`"All tests"` / `"Selected tests"`, then `"<target>.xctest"`) that modern omits. Same keys, more depth. |
| `durations` | `duration` is a real number on legacy but `0` on modern for every group and every Swift Testing test case — the modern format reports `null` there. XCTest iteration durations agree to within a millisecond but are **not** byte-identical: the two formats report them from different documents. Treat every `duration` as a per-backend measurement, not a comparison key. |

**Class 2 — a model-level capability difference:** `testCase.arguments` is
populated on the modern reader for parameterized Swift Testing cases and
always `[]` on legacy, which has no counterpart in its format. This is not
an allow-list rule — nothing in the HTML renders it — and consumers
comparing backends must compare it separately rather than expecting
equality.

## What is deliberately not in the schema

- **Backend-internal handles.** The readers carry opaque references (log
  CAS ids, attachment payload uuids) that are meaningless outside the
  process and could never agree across backends. They are not emitted.
- **The `@Test` display name.** Only the modern format carries it; a field
  one backend can never fill does not enter the port, so it cannot enter
  this schema. `name` is the function-form name on both.
- **Anything the HTML report derives.** Mixed status, per-status counts,
  CSS classes: all foldable from the wire values above.

## Worked example

The complete, unedited document for `SanityResults.xcresult` (one passing
test with one attachment), modern reader:

```json
{
  "runs" : [
    {
      "destination" : {
        "deviceIdentifier" : "E9620177-E008-4401-BF1B-930A418C0E4C",
        "displayName" : "iPhone 17 Pro Max",
        "modelName" : "iPhone 17 Pro Max",
        "operatingSystemVersion" : "26.2"
      },
      "testables" : [
        {
          "groups" : [
            {
              "children" : [
                {
                  "arguments" : [

                  ],
                  "identifier" : "FirstSuite/testOne()",
                  "iterations" : [
                    {
                      "activities" : [
                        {
                          "attachments" : [

                          ],
                          "isFailure" : false,
                          "start" : "2026-08-13T04:32:50.670Z",
                          "subActivities" : [

                          ],
                          "title" : "Start Test at 2026-08-12 21:32:50.670"
                        },
                        {
                          "attachments" : [

                          ],
                          "isFailure" : false,
                          "start" : "2026-08-13T04:32:50.688Z",
                          "subActivities" : [

                          ],
                          "title" : "Set Up"
                        },
                        {
                          "attachments" : [
                            {
                              "filename" : "0~Y_cC85cDZmf7QR61P4GJIWMU5YMbJQjJCzkyt-5XQzFmHVAST7N8yUdK30t5orGbr_vNDCMf3uVTLaODuu7Gpw==.txt",
                              "filenameExtension" : "txt",
                              "name" : null
                            }
                          ],
                          "isFailure" : false,
                          "start" : "2026-08-13T04:32:50.688Z",
                          "subActivities" : [

                          ],
                          "title" : "Text Attachment"
                        },
                        {
                          "attachments" : [

                          ],
                          "isFailure" : false,
                          "start" : "2026-08-13T04:32:50.688Z",
                          "subActivities" : [

                          ],
                          "title" : "Tear Down"
                        }
                      ],
                      "duration" : 0.06264996528625488,
                      "iterationNumber" : null,
                      "status" : "passed"
                    }
                  ],
                  "kind" : "testCase",
                  "name" : "testOne()"
                }
              ],
              "duration" : 0,
              "identifier" : "FirstSuite",
              "kind" : "group",
              "name" : "FirstSuite"
            }
          ],
          "targetName" : "SampleAppUITests"
        }
      ]
    }
  ],
  "schemaVersion" : "1.0.0"
}
```

## Version policy

`schemaVersion` is semver, and this document is versioned with it:

- **Major** — anything that can break a consumer: a key removed or renamed,
  a type or the null rule changed, an enum value removed or renamed, an
  ordering guarantee weakened, meaning changed.
- **Minor** — additive only: a new key, a new enum value. Consumers must
  ignore keys they do not recognise, so minor bumps are safe to take
  blindly.
- **Patch** — clarifications to this document; the bytes consumers see do
  not change shape.

**Consumer guidance:** read `schemaVersion` first. Accept any `1.x.y`,
ignoring unknown keys; refuse anything with a different major and say which
version you expected. Do not sniff for individual keys as a version probe —
the field exists so you never have to.
