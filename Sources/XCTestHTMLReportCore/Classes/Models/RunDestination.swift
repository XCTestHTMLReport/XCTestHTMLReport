//
//  RunDestination.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

/// Where one run executed.
///
/// This stopped rendering itself in A3a (#439). It used to own the device
/// sidebar's card — name, OS, model and the report's own element handle,
/// stacked in a `<ul>` with a click handler on it — and the sidebar is gone.
/// What replaced it, the header device picker, needs the run's *tally* beside
/// each destination, which this type has no way to reach, so the picker is
/// built by `RunSummary` (see `RunSummary+HTML.deviceOption`) from a view
/// model that holds both. This is now a plain value the rest of the report
/// reads fields out of.
///
/// `status` went with the markup. It was never derived — a standing `TODO`
/// left it hardcoded to `.unknown`, and the sidebar's icon rule drew nothing
/// at all for that case, so every card in every report ever rendered showed a
/// blank status cell. The picker states the real outcome, taken from
/// `Run.status`, which is the same value the summary band's bars are built
/// from.
struct RunDestination {
    let name: String
    let targetDevice: TargetDevice

    init(destination: ParsedDestination, identifierPath: IdentifierPath) {
        Logger.substep("Parsing run destination")
        name = destination.displayName
        targetDevice = TargetDevice(
            destination: destination,
            identifierPath: identifierPath.appending("device")
        )
    }
}
