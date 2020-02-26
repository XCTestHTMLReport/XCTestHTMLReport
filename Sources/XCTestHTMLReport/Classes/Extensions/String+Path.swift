//
//  String+Path.swift
//  XCTestHTMLReport
//
//  Created by Titouan Van Belle on 26.11.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

extension String
{
    func lastPathComponent() -> String
    {
        return URL(fileURLWithPath: self).lastPathComponent
    }

    func dropLastPathComponent() -> String
    {
        return URL(fileURLWithPath: self).deletingLastPathComponent().path
    }

    func addPathComponent(_ component: String) -> String
    {
        return URL(fileURLWithPath: self).appendingPathComponent(component).path
    }
}
