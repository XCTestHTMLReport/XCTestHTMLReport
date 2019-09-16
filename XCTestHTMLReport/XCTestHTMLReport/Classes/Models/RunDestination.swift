//
//  RunDestination.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

private extension Status {
    /// e.g. <span class="icon left failure"></span>
    var iconCssClass: String {
        switch self {
        case .failure:
            return "failure"
        case .success:
            return "success"
        default:
            return ""
        }
    }

    /// Only show icon for failures
    var iconHTML: String {
        guard self == .failure ||
              self == .success else {
            return ""
        }
        return "<span class=\"device-result icon left \(iconCssClass)\"></span>"
    }
}

/// Represents single test device attributes
struct RunDestination : HTML
{
    var name: String
    var targetDevice: TargetDevice
    var status: Status = .unknown

    init(dict: [String : Any])
    {
        Logger.substep("Parsing RunDestination")
        
        name = dict["Name"] as! String
        targetDevice = TargetDevice(dict: dict["TargetDevice"] as! [String : Any])
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.device

    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_RESULT": status.iconHTML,
            "DEVICE_NAME": name,
            "DEVICE_IDENTIFIER": targetDevice.uniqueIdentifier,
            "DEVICE_MODEL": targetDevice.model,
            "DEVICE_OS": targetDevice.osVersion,
        ]
    }
}
