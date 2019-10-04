//
//  RunDestination.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct TargetDevice
{
    let identifier: String
    let uniqueIdentifier: String
    let osVersion: String
    let model: String

    init(record: ActionDeviceRecord) {
        Logger.substep("Parsing ActionDeviceRecord")
        self.identifier = record.identifier
        self.uniqueIdentifier = UUID().uuidString
        self.osVersion = record.operatingSystemVersion
        self.model = record.modelName
    }
}

