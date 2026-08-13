//
//  ResultBackend.swift
//  XCTestHTMLReportCore
//

import Foundation

/// Which reader parses result bundles.
///
/// `LegacyCapability` lives in `XCResultToolClient.swift`: the client probes
/// the toolchain once per process and caches the answer there.
public enum ResultBackend: String, CaseIterable {
    /// Prefer `legacy` while the toolchain still offers the legacy commands.
    case auto
    case legacy
    case modern

    /// Outcome of resolving a request against the toolchain's capability.
    public enum Resolution: Equatable {
        case use(ResultBackend)
        /// An explicit `legacy` request the toolchain cannot honour.
        case legacyUnavailable
    }

    /// Only `auto` ever substitutes.
    ///
    /// An explicit `--result-reader legacy` that cannot be honoured is an
    /// error, never a silent downgrade. Substituting would let a modern-only
    /// host run the modern reader twice and report the differential as
    /// passing — comparing a backend against itself and calling it parity.
    ///
    /// `unknown` (an unparseable version string) is not proof of absence:
    /// `auto` degrades to `.modern` because working beats broken, while an
    /// explicit `legacy` attempts legacy anyway and lets any resulting command
    /// failure surface as a fault rather than as a capability signal.
    public func resolve() -> Resolution {
        switch (self, XCResultToolClient.legacyCapability) {
        case (.modern, _):
            return .use(.modern)
        case (.legacy, .available), (.legacy, .unknown):
            return .use(.legacy)
        case (.legacy, .unavailable):
            return .legacyUnavailable
        case (.auto, .available):
            return .use(.legacy)
        case (.auto, .unknown), (.auto, .unavailable):
            return .use(.modern)
        }
    }
}
