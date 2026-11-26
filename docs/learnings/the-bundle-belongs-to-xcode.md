# Everything in a result bundle belongs to Xcode except our exports

`-d` was written for the Xcode 10 bundle layout, where attachments were plain
files the report could link or leave out. It spared only names the report
linked, and deleted everything else at the bundle's top level and in `Data/`.
On a modern bundle that is `Info.plist`, `database.sqlite3` and Xcode's whole
object store (`data.0~…`, `refs.0~…`). The run still exited 0, and the
`.xcresult` could no longer be opened by Xcode or `xcresulttool` (#220).

Since Xcode 11, every object in `Data/` is reachable from the bundle's own
graph, so none of them is an "unused attachment". That includes the attachment
payloads the report has already exported. The only files in a bundle that this
tool may delete are the ones it wrote itself: `0~<payload id>[.<ext>]` and
`<32 hex>.log` at the top level (`isOwnExportFileName`).

**Before deleting or rewriting anything inside an `.xcresult`, prove this tool
wrote it.** Spare-by-allowlist ("keep what the report links") deletes whatever
you did not think of. Delete-by-allowlist ("remove only names we write")
cannot. Then check that `xcrun xcresulttool get test-results summary` still
reads the bundle afterwards.
