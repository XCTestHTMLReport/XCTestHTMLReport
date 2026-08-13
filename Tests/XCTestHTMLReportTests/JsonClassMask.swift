//
//  JsonClassMask.swift
//
//  The `--json` cross-backend comparison's masking layer — the JSON
//  counterpart of `KnownLossMasker`, which does the same job for rendered
//  HTML. Applies exactly the declared value-difference classes and nothing
//  else:
//
//  - `wrapperGroups` (class 1): legacy-only, wrapper levels splice out.
//  - `durations` (class 1): every `duration` becomes 0 on both sides.
//  - `attachmentDisplayNames` (class 1): `attachment.name` blanks on legacy;
//    on modern it must already be null and is counted, not blanked.
//  - `failureTitlePrefix` (class 1): the `title` of rows whose `isFailure`
//    is true blanks on both sides.
//  - `arguments` (class 2): blanks on both sides; the values themselves are
//    asserted separately, never by cross-backend equality.
//
//  `Stats` is how the caller keeps the masks honest: a mask that had nothing
//  to remove is masking a divergence that no longer exists.
//

import Foundation

enum JsonClassMask {
    // MARK: Internal

    struct Stats {
        var unwrappedWrapperGroups = 0
        var modernAttachmentNames = 0
    }

    static func masked(_ any: Any, legacy: Bool, stats: inout Stats) -> Any {
        switch any {
        case let dict as [String: Any]:
            return masked(dictionary: dict, legacy: legacy, stats: &stats)
        case let array as [Any]:
            return array.map { masked($0, legacy: legacy, stats: &stats) }
        default:
            return any
        }
    }

    /// Deterministic text for deep comparison with a readable diff.
    static func canonical(_ object: Any) -> String {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: object, options: [.prettyPrinted, .sortedKeys]
            )
        else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: Private

    private static let wrapperNames: Set<String> = ["All tests", "Selected tests"]

    private static func masked(
        dictionary: [String: Any], legacy: Bool, stats: inout Stats
    ) -> [String: Any] {
        var dict = dictionary
        for (key, value) in dict {
            dict[key] = masked(value, legacy: legacy, stats: &stats)
        }
        maskScalars(&dict)
        maskAttachmentName(&dict, legacy: legacy, stats: &stats)
        unwrapWrapperGroups(&dict, legacy: legacy, stats: &stats)
        return dict
    }

    private static func maskScalars(_ dict: inout [String: Any]) {
        if dict["duration"] != nil {
            dict["duration"] = 0
        }
        if dict["arguments"] != nil {
            dict["arguments"] = [String]()
        }
        if dict["isFailure"] as? Bool == true {
            dict["title"] = ""
        }
    }

    /// An attachment is the only object carrying `filenameExtension`.
    private static func maskAttachmentName(
        _ dict: inout [String: Any], legacy: Bool, stats: inout Stats
    ) {
        guard dict.keys.contains("filenameExtension") else {
            return
        }
        if legacy {
            dict["name"] = NSNull()
        } else if !(dict["name"] is NSNull) {
            stats.modernAttachmentNames += 1
        }
    }

    private static func isWrapperGroup(_ dict: [String: Any]) -> Bool {
        guard dict["kind"] as? String == "group", let name = dict["name"] as? String
        else {
            return false
        }
        return wrapperNames.contains(name) || name.hasSuffix(".xctest")
    }

    private static func unwrapWrapperGroups(
        _ dict: inout [String: Any], legacy: Bool, stats: inout Stats
    ) {
        for key in ["groups", "children"] {
            guard let nodes = dict[key] as? [[String: Any]] else {
                continue
            }
            dict[key] = nodes.flatMap { node -> [[String: Any]] in
                guard legacy, isWrapperGroup(node) else {
                    return [node]
                }
                stats.unwrappedWrapperGroups += 1
                return node["children"] as? [[String: Any]] ?? []
            }
        }
    }
}
