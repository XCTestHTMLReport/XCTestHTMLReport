//
//  JUnitRepresentable.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 01.05.18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

protocol JUnitRepresentable
{
    func junit(includeRunDestinationInfo: Bool) -> JUnitReport
}
