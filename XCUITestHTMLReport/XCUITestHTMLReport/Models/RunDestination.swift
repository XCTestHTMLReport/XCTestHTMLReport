//
//  RunDestination.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct RunDestination
{
    var name: String
    var targetDevice: TargetDevice

    init(dict: [String : Any])
    {
        Logger.substep("Parsing RunDestination")
        
        name = dict["Name"] as! String
        targetDevice = TargetDevice(dict: dict["TargetDevice"] as! [String : Any])
    }
}
