//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

public struct Summary {
    let runs: [Run]
    /// The backend-neutral model the runs were built from, retained so
    /// `generatedJsonReport()` can emit it without a second parse.
    private let parsedRuns: [ParsedRun]
    private let faultCollector: FaultCollector
    /// Bundle file names in argument order, duplicates collapsed. Retained
    /// only to title the page — see `title`.
    private let bundleNames: [String]

    public enum RenderingMode {
        case inline
        case linking
    }

    /// All degradation encountered while building this report.
    public var faults: [Fault] {
        faultCollector.faults
    }

    public init(
        resultPaths: [String],
        renderingMode: RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat,
        faultCollector: FaultCollector = FaultCollector(),
        backend: ResultBackend = .fromEnvironment()
    ) {
        var runs: [Run] = []
        var parsedRuns: [ParsedRun] = []
        self.faultCollector = faultCollector

        bundleNames = Self.bundleNames(from: resultPaths)

        // The CLI already rejects an explicit `legacy` the toolchain cannot
        // honour in `validate()`. This arm is defence in depth for library
        // consumers who never pass through the CLI: a non-throwing init
        // cannot raise the error, so it records a fault — which reaches
        // exit 3 through the existing path, and is therefore still not a
        // silent substitution.
        let resolved: ResultBackend
        switch backend.resolve() {
        case let .use(concrete):
            resolved = concrete
        case .legacyUnavailable:
            faultCollector.record(
                .legacyReaderUnavailable,
                "legacy reader requested but unavailable on this toolchain"
            )
            resolved = .modern
        }

        for (resultIndex, resultPath) in resultPaths.enumerated() {
            Logger.step("Parsing \(resultPath)")
            let url = URL(fileURLWithPath: resultPath)
            let resultFile = ResultFile(url: url, faultCollector: faultCollector)

            let (reader, payloads) = Self.makeReader(
                resolved: resolved,
                resultFile: resultFile,
                faultCollector: faultCollector
            )

            guard let parsed = reader.read() else {
                Logger.warning("Can't find invocation record for : \(resultPath)")
                faultCollector.record(.missingInvocationRecord, resultPath)
                // Previously `break`, which silently abandoned every remaining
                // bundle when multiple were passed.
                continue
            }
            parsedRuns.append(contentsOf: parsed.runs)
            // Identifiers are derived from the bundle's position in the
            // argument list rather than from its path, so moving a bundle
            // between directories still renders the same report. See
            // `IdentifierPath`.
            let resultRuns = parsed.runs.enumerated()
                .compactMap { actionIndex, run in
                    Run(
                        run: run,
                        identifierPath: IdentifierPath.root
                            .appending("bundle\(resultIndex)")
                            .appending("action\(actionIndex)"),
                        file: payloads,
                        renderingMode: renderingMode,
                        downsizeImagesEnabled: downsizeImagesEnabled,
                        downsizeScaleFactor: downsizeScaleFactor
                    )
                }
            runs.append(contentsOf: resultRuns)
        }
        self.runs = runs
        self.parsedRuns = parsedRuns
    }

    /// Builds a summary from already-parsed runs, bypassing result reading.
    ///
    /// #391 made `ParsedResult` the contract between reading and rendering;
    /// this injects at that boundary rather than bolting a back door onto an
    /// unrelated type. Tests use it to render from constants, which is what
    /// makes committed golden files possible at all — renders driven by the
    /// generated .xcresult fixtures cannot support one, because the fixtures
    /// are regenerated on every run.
    ///
    /// Internal, not public, because `PayloadProviding` is internal.
    /// `@testable import` reaches it; library consumers keep the path-based
    /// initialiser.
    init(
        parsedRuns: [ParsedRun],
        payloads: PayloadProviding,
        renderingMode: RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat,
        faultCollector: FaultCollector = FaultCollector(),
        bundleNames: [String]
    ) {
        self.faultCollector = faultCollector
        self.bundleNames = bundleNames
        self.parsedRuns = parsedRuns
        // Mirrors the path-based initialiser's shape above
        // (`bundle\(resultIndex)`/`action\(actionIndex)`), rather than the
        // unrelated `run-\(index)`, so the goldens pin an identifier set a
        // real report could actually produce. There is one synthetic action
        // per run here, hence the literal `action0`.
        runs = parsedRuns.enumerated().compactMap { index, run in
            Run(
                run: run,
                identifierPath: IdentifierPath.root
                    .appending("bundle\(index)")
                    .appending("action0"),
                file: payloads,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            )
        }
    }

    /// Bundle file names for the title, in argument order.
    ///
    /// Names, not paths: the title has to survive a bundle moving directories
    /// for the same reason the identifiers minted in `init` do. Duplicates are
    /// collapsed because the same bundle may legitimately be passed twice.
    private static func bundleNames(from resultPaths: [String]) -> [String] {
        var seen = Set<String>()
        return resultPaths.compactMap { path in
            let name = URL(fileURLWithPath: path)
                .deletingPathExtension()
                .lastPathComponent
            guard !name.isEmpty, seen.insert(name).inserted else {
                return nil
            }
            return name
        }
    }

    /// Reader and payload provider for one bundle on the resolved backend.
    private static func makeReader(
        resolved: ResultBackend,
        resultFile: ResultFile,
        faultCollector: FaultCollector
    ) -> (reader: ResultReader, payloads: PayloadProviding) {
        switch resolved {
        case .legacy, .auto:
            // `resolve()` never returns `.use(.auto)`, so the `.auto` arm is
            // unreachable; it exists because `ResultBackend` is the parameter
            // type and Swift requires exhaustiveness.
            return (LegacyResultReader(file: resultFile), resultFile)
        case .modern:
            let client = XCResultToolClient(bundleURL: resultFile.url)
            let store = ModernPayloadStore(
                client: client, bundleURL: resultFile.url, faultCollector: faultCollector
            )
            let reader = ModernResultReader(
                client: client, payloadStore: store, faultCollector: faultCollector
            )
            return (reader, store)
        }
    }

    /// Generate HTML report
    /// - Returns: Generated HTML report string
    public func generatedHtmlReport() -> String {
        html
    }

    /// Generate JUnit report
    /// - Returns: Generated JUnit XML report string
    public func generatedJunitReport(includeRunDestinationInfo: Bool) -> String {
        junit(includeRunDestinationInfo: includeRunDestinationInfo).xmlString
    }

    /// Delete all unattached files in runs
    public func deleteUnattachedFiles() {
        Logger.substep("Deleting unattached files..")
        var deletedFilesCount = 0
        deletedFilesCount = removeUnattachedFiles(runs: runs)
        Logger.substep("Deleted \(deletedFilesCount) unattached files")
    }

    /// Emits the parsed model as JSON, per the contract in
    /// docs/json-schema.md.
    ///
    /// Before 4.0 this dumped `xcresulttool`'s legacy object graph verbatim.
    /// That graph is Apple's internal shape and disappears with the legacy
    /// commands, so the output is now our own documented, versioned schema —
    /// identical on both backends.
    public func generatedJsonReport() -> String {
        JsonReport(runs: parsedRuns).encoded()
    }

    /// Check post-conditions on the assembled model and record any degradation.
    ///
    /// Call-site checks catch failures XCResultKit surfaces as `nil`. They do
    /// not catch failures in *nested* decoding, where a parent object still
    /// decodes but a child field comes back empty. The observable symptoms are
    /// an attachment whose payload resolved to no content and a run whose log
    /// reference resolved to no content, so check for both directly.
    /// Attachments that never had a payload and runs that never had a log
    /// reference are skipped: their content is empty by construction, not
    /// through degradation (#387, #386).
    ///
    /// Idempotent across sequential calls: repeated calls do not duplicate
    /// faults. Dedup keys on `Attachment.faultDescription` and
    /// `Run.logFaultDescription`, which assume `allAttachments` and `runs` are
    /// stable for this value's lifetime — they are, since `runs` is a `let`.
    /// Not safe to call concurrently with itself: the read of `faults` and the
    /// subsequent `record` are separately synchronized, not atomic as a unit.
    public func validate() {
        let recorded = faultCollector.faults
        let flaggedAttachments = Set(
            recorded.filter { $0.kind == .unresolvedAttachment }.map(\.detail)
        )
        let flaggedLogs = Set(
            recorded.filter { $0.kind == .unresolvedLog }.map(\.detail)
        )

        for attachment in allAttachments {
            guard attachment.failedToResolve else {
                continue
            }
            let detail = attachment.faultDescription
            guard !flaggedAttachments.contains(detail) else {
                continue
            }
            faultCollector.record(.unresolvedAttachment, detail)
        }

        for run in runs {
            guard run.logFailedToResolve else {
                continue
            }
            let detail = run.logFaultDescription
            guard !flaggedLogs.contains(detail) else {
                continue
            }
            faultCollector.record(.unresolvedLog, detail)
        }
    }
}

extension Summary {
    /// Tab title. Constant `XCHTMLReport` until #439: parked tabs from
    /// different runs were indistinguishable (UI audit, finding 7).
    ///
    /// Derived from the bundle file names rather than from anything read out
    /// of a bundle, which keeps it byte-identical across the legacy and
    /// modern readers — the differential gate holds by construction rather
    /// than by allow-list. Falls back to the product name when no bundle
    /// yielded a usable name, so the title is never empty.
    var title: String {
        guard !bundleNames.isEmpty else {
            return "XCTestHTMLReport"
        }
        return "\(bundleNames.joined(separator: ", ")) — XCTestHTMLReport"
    }
}

extension Summary: HTML {
    var htmlTemplate: String {
        HTMLTemplates.index
    }

    var htmlPlaceholderValues: [String: String] {
        let resultClass: String
        if runs.contains(where: { $0.status == .failure }) {
            resultClass = "failure"
        } else if runs.contains(where: { $0.status == .success }) {
            resultClass = "success"
        } else {
            resultClass = "skip"
        }
        return [
            "DEVICES": runs.map(\.runDestination.html).joined(),
            "RESULT_CLASS": resultClass,
            "RUNS": runs.map(\.html).joined(),
            "TITLE": title.stringByEscapingXMLChars,
        ]
    }
}

extension Summary: JUnitRepresentable {
    func junit(includeRunDestinationInfo: Bool) -> JUnitReport {
        JUnitReport(summary: self, includeRunDestinationInfo: includeRunDestinationInfo)
    }
}

extension Summary: ContainingAttachment {
    var allAttachments: [Attachment] {
        runs.map(\.allAttachments).reduce([], +)
    }
}
