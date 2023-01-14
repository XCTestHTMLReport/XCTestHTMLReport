//
//  String+Path.swift
//  XCTestHTMLReport
//
//  Created by Titouan Van Belle on 26.11.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

public extension String {
    func lastPathComponent() -> String {
        URL(fileURLWithPath: self).lastPathComponent
    }

    func dropLastPathComponent() -> String {
        URL(fileURLWithPath: self).deletingLastPathComponent().path
    }

    func addPathComponent(_ component: String) -> String {
        URL(fileURLWithPath: self).appendingPathComponent(component).path
    }
}
