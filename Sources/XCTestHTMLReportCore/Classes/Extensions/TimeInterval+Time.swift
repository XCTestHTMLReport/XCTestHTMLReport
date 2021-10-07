//
//  TimeInterval+Time.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 27.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

extension TimeInterval
{
    var timeString: String
    {
        let ti = Int(self)

        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)

        if hours > 0 {
            return String(format: "%dh%0.2dm%0.2ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm%0.2ds", minutes, seconds)
        }

        return String(format: "%ds", seconds)
    }
}

