# SwiftSoup serializes an unmodified element from its source bytes

Since SwiftSoup 2.13.9 (scinfu/SwiftSoup#409), `outerHtml()` copies an
element's original source text when that element has not been modified, and
re-serializes only what was changed. The output of parse-then-serialize
therefore depends on what was edited, not just on the tree it holds.

`KnownLossMasker`'s `wrapperGroups` rule parses both backends' renders and
serializes them back. The legacy render has wrapper groups to unwrap, the modern
one does not, so after the 2.14.4 bump (#519) the document shell came back
normalised on one side and as written on the other:

    legacy: <!doctype html><html lang="en"><head>
    modern: <!doctype html><html lang="en">
            <head>

That gave six differing lines per fixture, with identical content.

**When a test compares two serializations, call
`outerHtmlUTF8WithoutSourceReuse()`**, which re-serializes every node (the
2.13.7 behaviour). `Package.swift` requires SwiftSoup 2.13.8 or later, the
first version with that API. It does not matter for a test that only queries
the parsed tree.
