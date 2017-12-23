//
//  RunDestination.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct RunDestination : HTML
{
    var name: String
    var targetDevice: TargetDevice

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
            "DEVICE_NAME": name,
            "DEVICE_IDENTIFIER": targetDevice.identifier,
            "DEVICE_MODEL": targetDevice.model,
            "DEVICE_OS": targetDevice.osVersion,
        ]
    }
}
