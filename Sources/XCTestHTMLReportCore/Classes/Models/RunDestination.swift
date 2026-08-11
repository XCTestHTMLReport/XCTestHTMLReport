//
//  RunDestination.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

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

private extension ActionSDKRecord {
    var operatingSystemName: String {
        let simulatorPrefix = "Simulator - "
        let platformAndVersion = name.hasPrefix(simulatorPrefix)
            ? String(name.dropFirst(simulatorPrefix.count))
            : name
        let versionSuffix = " \(operatingSystemVersion)"

        guard platformAndVersion.hasSuffix(versionSuffix) else {
            return platformAndVersion
        }
        return String(platformAndVersion.dropLast(versionSuffix.count))
    }
}

struct RunDestination: HTML {
    let name: String
    let operatingSystemName: String
    let targetDevice: TargetDevice
    let status: Status

    init(record: ActionRunDestinationRecord) {
        Logger.substep("Parsing ActionRunDestinationRecord")
        name = record.displayName
        operatingSystemName = record.targetSDKRecord.operatingSystemName
        targetDevice = TargetDevice(record: record.targetDeviceRecord)
        status = .unknown // TODO: (Pierre Felgines) 04/10/2019 Find the correct value
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.device

    var htmlPlaceholderValues: [String: String] {
        [
            "DEVICE_RESULT": status.iconHTML,
            "DEVICE_NAME": name,
            "DEVICE_IDENTIFIER": targetDevice.uniqueIdentifier,
            "DEVICE_MODEL": targetDevice.model,
            "DEVICE_OS_NAME": operatingSystemName,
            "DEVICE_OS": targetDevice.osVersion,
        ]
    }
}
