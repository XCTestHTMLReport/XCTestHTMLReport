# SwiftSoup serializes unedited nodes from their source bytes

With `prettyPrint(false)`, SwiftSoup's `outerHtml()` copies the source text of
nodes that were not edited, so parse-then-serialize depends on what was edited
as well as on the tree. What counts as edited has shifted between releases. In
2.13.7, one edit anywhere rebuilt the whole document, while an unedited
document kept its body as written. From 2.13.9 (scinfu/SwiftSoup#409) only
edited nodes and their ancestors are rebuilt, and an unedited document keeps
its `<html>`/`<body>` shell as written as well.

`KnownLossMasker`'s `wrapperGroups` rule parses both backends' renders and
serializes them back. Only the legacy render has wrapper groups to unwrap, so
after the 2.14.4 bump (#519) the document shell came back rebuilt on one side
and as written on the other:

    legacy: <!doctype html><html lang="en"><head>
    modern: <!doctype html><html lang="en">
            <head>

That gave six differing lines per fixture, with identical content. Before the
bump the comparison was already raw bytes (modern) against fully rebuilt output
(legacy). It passed only because the template emits canonical markup.

**When a test compares two serializations, call
`outerHtmlUTF8WithoutSourceReuse()`.** It rebuilds every node, so it compares
the trees and not their source spellings (`'a'` and `"a"` read the same). It
first shipped in 2.13.8, the minimum `Package.swift` now requires. Tests that
only query the parsed tree are unaffected.
