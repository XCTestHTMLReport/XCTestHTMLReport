//
//  EmittableOutput.swift
//  Rainbow
//
//  Created by Pierre Felgines on 08/10/2019.
//

import Foundation
import XCResultKit

protocol EmittableOutput {
    func formatEmittedOutput() -> String
}

extension ActivityLogUnitTestSection: EmittableOutput {

    // Recursively collect emitted output from each subsection, adding an additional indent to each nested log
    // This is how test steps are formatted in Xcode, including the repeated log lines
    func formatEmittedOutput() -> String {
        "-------- \(title) --------\n" +
        (emittedOutput ?? "") +
        subsections
            .compactMap {
                "\t" + $0.formatEmittedOutput()
                    .split(separator: "\n")
                    .joined(separator: "\n\t")
            }
            .joined(separator: "\n")
    }

}

extension ActivityLogSection: EmittableOutput {

    func formatEmittedOutput() -> String {
        "\(title)\n\n" + subsections
            .compactMap { $0.formatEmittedOutput() }
            .joined(separator: "\n")
    }

}
