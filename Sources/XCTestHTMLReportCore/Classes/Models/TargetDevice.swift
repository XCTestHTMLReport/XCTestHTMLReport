//
//  TargetDevice.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct TargetDevice {
    let identifier: String

    /// Addresses this device's run in the rendered page: the run element is
    /// `id="device_<uniqueIdentifier>"` and the device selector calls
    /// `selectDevice('<uniqueIdentifier>')`.
    ///
    /// Not `record.identifier` on its own. One report can hold several runs
    /// against the same physical device — merged bundles, or a bundle passed
    /// twice — and they would then share an element id, which fails silently:
    /// `querySelectorAll('#device_…')[0]` picks the first match, so selecting
    /// the second device would activate the first one's results.
    let uniqueIdentifier: String

    let osVersion: String
    let model: String

    init(destination: ParsedDestination, identifierPath: IdentifierPath) {
        Logger.substep("Parsing target device")
        identifier = destination.deviceIdentifier
        uniqueIdentifier = identifierPath.appending(destination.deviceIdentifier).identifier
        osVersion = destination.operatingSystemVersion
        model = destination.modelName
    }
}
