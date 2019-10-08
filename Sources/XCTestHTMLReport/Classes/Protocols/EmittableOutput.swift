//
//  EmittableOutput.swift
//  Rainbow
//
//  Created by Pierre Felgines on 08/10/2019.
//

import Foundation
import XCResultKit

protocol EmittableOutput {
    var emittedOutput: String? { get }
}

extension ActivityLogUnitTestSection: EmittableOutput {}


extension ActivityLogSection: EmittableOutput {

    var emittedOutput: String? {
        return "\(title)\n\n"
            + subsections
                .compactMap { $0.emittedOutput }
                .joined(separator: "\n")
    }
}

extension ActivityLogMajorSection: EmittableOutput {

    var emittedOutput: String? {
        return "\(title) - \(subtitle)\n\n"
            + unitTestSubsections
                .compactMap { $0.emittedOutput }
                .joined(separator: "\n")
    }
}

