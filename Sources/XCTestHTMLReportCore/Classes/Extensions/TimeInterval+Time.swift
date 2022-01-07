//
//  TimeInterval+Time.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 27.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

extension TimeInterval {
    var formattedSeconds: String {
        String(format: "%.2fs", self)
    }
}
