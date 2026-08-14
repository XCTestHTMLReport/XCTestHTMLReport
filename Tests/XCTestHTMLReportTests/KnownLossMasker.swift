//
//  KnownLossMasker.swift
//
//  Removes exactly the differences declared in differential-allowlist.json
//  from a rendered report, so the differential test can assert that what
//  remains is identical across backends.
//
//  Each rule here corresponds 1:1 to an allow-list entry, by name. Adding a
//  rule without adding the entry (or vice versa) fails
//  testEveryAllowListRuleIsImplemented.
//

import Foundation
import SwiftSoup

enum KnownLossMasker {
    /// Four, not five. `activityTypeClasses` was removed by decision 2: with no
    /// `activityType` in the port, both backends render the same thing and there
    /// is nothing to mask.
    ///
    /// `durations` stays. An earlier revision deleted it too, on the premise
    /// that removing `ParsedActivity.finish` removed all duration divergence.
    /// That was wrong — the surviving divergence is in group durations, which
    /// `finish` never fed.
    static let implementedRules: Set<String> = [
        "durations",
        "attachmentDisplayNames",
        "failureTitlePrefix",
        "wrapperGroups",
    ]

    static func mask(_ html: String, rules: [String]) -> String {
        var masked = html
        for rule in rules {
            masked = apply(rule, to: masked)
        }
        // Canonicalize line shape before comparing. Template concatenation
        // joins adjacent sibling blocks onto one line (`</div>  <div …>`), and
        // *which* boundaries join depends on nesting depth — so the same DOM
        // can line-break differently across backends once the wrapper levels
        // are unwrapped. Splitting adjacent tags onto their own lines removes
        // the artifact symmetrically without touching content; the earlier
        // rules have already masked every unescaped text line this could
        // otherwise bite (attachment names). Then collapse the whitespace-only
        // lines the removals leave behind.
        masked = replace(masked, #">[ \t]+<"#, with: ">\n<")
        return masked
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Which rules actually mask a real divergence between these two renders.
    ///
    /// A rule "fires" when leaving it out (with every other rule still
    /// applied) leaves the two renders unequal — i.e. the rule is necessary,
    /// not merely matching. This is the anti-rot probe: once Apple fills a
    /// gap, the divergence disappears, the rule stops being necessary, and
    /// `testEveryAllowListEntryStillMasksARealDivergence` fails until the
    /// entry is deleted. Only meaningful once the fully-masked renders are
    /// equal — while they differ, omitting any rule trivially leaves them
    /// unequal and every rule reports as firing.
    static func firedRules(legacy: String, modern: String, rules: [String]) -> Set<String> {
        var fired: Set<String> = []
        for rule in rules {
            let others = rules.filter { $0 != rule }
            if mask(legacy, rules: others) != mask(modern, rules: others) {
                fired.insert(rule)
            }
        }
        return fired
    }

    private static func apply(_ rule: String, to html: String) -> String {
        switch rule {
        case "durations":
            // Bare `(1.23s)` / `(0.00s)` suffixes from `[[TITLE]] ([[DURATION]])`.
            //
            // Deliberately over-broad, and that costs coverage. The divergence
            // is in group headings and Swift Testing cases, but the rendered
            // form is identical for every row and the duration sits on a
            // different line from the `test-summary-group` class, so it cannot
            // be scoped by line. Normalising all of them therefore also hides
            // any regression in *XCTest* case durations, which do agree.
            //
            // `testXCTestCaseDurationsAgreeAcrossBackends` restores exactly
            // that coverage. Do not delete one without the other.
            return replace(html, #"\(\d+\.\d+s\)"#, with: "(DURATION)")
        case "attachmentDisplayNames":
            // The `[[NAME]]` line inside `<p class="attachment list-item">`.
            // It is the third template line — the type-icon `<span>` sits
            // between the `<p>` and the name — so the anchor spans both
            // preceding lines. Anchoring on the icon span also keeps the rule
            // from ever touching a non-attachment `<p>`.
            //
            // `(?:left )?` because A2 (#439) made the row a flex line and
            // dropped the `left` float class from the type icon. The optional
            // group rather than a straight deletion: the anchor then matches
            // a report rendered by either revision, and since the rule is
            // still anchored on `<p class="attachment…">` above it, widening
            // it here cannot reach a `<p>` it did not already reach. The
            // replacement takes the whole name *line*, so it is indifferent
            // to the name having gained a `<span class="row-name">` wrapper —
            // both backends emit the wrapper, only the name inside it differs.
            let namedLines = replace(
                html,
                #"(<p class="attachment[^"]*">\n\s*<span class="icon (?:left )?[a-z-]*icon"[^\n]*></span>\n)[^\n]*\n"#,
                with: "$1ATTACHMENT_NAME\n"
            )
            // One divergence, two sites since #462: the same display name is
            // also the `alt` of every attachment-derived image. Masking only
            // the text line would let the `alt` reintroduce the difference
            // this entry already accounts for. Matched on an exact class so
            // the two `displayed-*` preview panes — whose `alt` is empty in
            // both backends — stay compared.
            return replace(
                namedLines,
                #"(<img class="(?:screenshot|screenshot-flow|screenshot-tail|gif)"[^\n]*?)alt="[^"]*""#,
                with: "$1alt=\"ATTACHMENT_NAME\""
            )
        case "failureTitlePrefix":
            // Two shapes, not one. Verified on `TestResults`:
            //   legacy  "Assertion Failure at FirstSuite.swift:86:XCTAssertTrue failed - Test
            //   failed"
            //   modern  "FirstSuite.swift:86: XCTAssertTrue failed - Test failed"
            // An earlier revision stripped only the legacy form, so modern's
            // own `<file>:<line>: ` prefix survived and every failing test
            // still differed after masking — the entry's justification claimed
            // a convergence the rule did not deliver.
            let legacyStripped = replace(
                html, #"[A-Za-z ]+ at [^\s:]+:\d+:\s*"#, with: ""
            )
            return replace(legacyStripped, #"[\w.+-]+\.swift:\d+:\s*"#, with: "")
        case "wrapperGroups":
            // Legacy-only wrapper levels: `Selected tests` / `All tests` and
            // `<target>.xctest`. Dropping only the heading *line* leaves the
            // wrapper's div skeleton and its closing tag behind (measured:
            // 12 residual lines per fixture), so the rule is structural — it
            // removes the wrapper element's own heading and hoists its
            // children, which also removes the matching close. Serialization
            // preserves the original whitespace (`prettyPrint(false)`), so
            // the other rules' line anchors survive; both renders pass
            // through the same parse-serialize path, so any parser
            // normalisation applies symmetrically.
            do {
                let document = try SwiftSoup.parse(html)
                document.outputSettings().prettyPrint(pretty: false)
                for group in try document.select("div.test-summary-group").array() {
                    guard let heading = group.children().first(where: { $0.tagName() == "p" })
                    else {
                        continue
                    }
                    let title = try heading.text()
                    let isWrapper = title.hasPrefix("All tests (")
                        || title.hasPrefix("Selected tests (")
                        || title.contains(".xctest (")
                    guard isWrapper else {
                        continue
                    }
                    for child in group.children()
                        where child.tagName() == "span" || child.tagName() == "p"
                    {
                        try child.remove()
                    }
                    try group.unwrap()
                }
                return try document.outerHtml()
            } catch {
                // An unparseable report would mask nothing and fail the
                // differential loudly, which is the right failure mode.
                return html
            }
        default:
            return html
        }
    }

    private static func replace(
        _ text: String, _ pattern: String, with template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
