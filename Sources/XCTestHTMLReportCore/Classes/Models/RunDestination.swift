//
//  RunDestination.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

// TODO: Check usages, Status already contains cssClass property
private extension Status {
    /// e.g. <span class="icon left failure"></span>
    var iconCssClass: String {
        switch self {
        case .failure:
            return "failure"
        case .success:
            return "success"
        case .skipped:
            return "skip"
        case .mixed:
            return "mixed"
        default:
            return ""
        }
    }

    /// Only show icon for failures
    var iconHTML: String {
        guard self == .failure ||
            self == .success
        else {
            return ""
        }
        return "<span class=\"device-result icon left \(iconCssClass)\"></span>"
    }
}

struct RunDestination: HTML {
    let name: String
    let targetDevice: TargetDevice
    let status: Status

    init(destination: ParsedDestination, identifierPath: IdentifierPath) {
        Logger.substep("Parsing run destination")
        name = destination.displayName
        targetDevice = TargetDevice(
            destination: destination,
            identifierPath: identifierPath.appending("device")
        )
        status = .unknown // TODO: (Pierre Felgines) 04/10/2019 Find the correct value
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.device

    var htmlPlaceholderValues: [String: String] {
        [
            "DEVICE_RESULT": status.iconHTML,
            "DEVICE_NAME": name.stringByEscapingXMLChars,
            "DEVICE_IDENTIFIER": targetDevice.uniqueIdentifier,
            "DEVICE_MODEL": targetDevice.model.stringByEscapingXMLChars,
            "DEVICE_OS": targetDevice.osVersion.stringByEscapingXMLChars,
        ]
    }
}
