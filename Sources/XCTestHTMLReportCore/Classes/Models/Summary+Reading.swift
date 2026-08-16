//
//  Summary+Reading.swift
//
//  Setup helpers for `Summary.init`'s read loop, kept beside it rather than in
//  it: the initialiser is long enough already, and these two answer questions
//  ("which backend?", "what is this phase called?") that are separable from
//  the loop that asks them.
//

import Foundation

extension Summary {
    /// The CLI already rejects an explicit `legacy` the toolchain cannot honour
    /// in `validate()`. This is defence in depth for library consumers who never
    /// pass through the CLI: a non-throwing init cannot raise the error, so it
    /// records a fault — which reaches exit 3 through the existing path, and is
    /// therefore still not a silent substitution.
    static func resolveBackend(
        _ backend: ResultBackend,
        faultCollector: FaultCollector
    ) -> ResultBackend {
        switch backend.resolve() {
        case let .use(concrete):
            return concrete
        case .legacyUnavailable:
            faultCollector.record(
                .legacyReaderUnavailable,
                "legacy reader requested but unavailable on this toolchain"
            )
            return .modern
        }
    }

    /// Only counted when there is more than one bundle: "(1 of 1)" is noise.
    static func readingPhaseLabel(path: String, index: Int, total: Int) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return total > 1 ? "Reading \(name) (\(index + 1) of \(total))" : "Reading \(name)"
    }
}
