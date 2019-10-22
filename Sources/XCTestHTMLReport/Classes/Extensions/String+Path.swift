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
    func dropLastPathComponent() -> String
    {
        if let url = URL(string: self) {
            return url.deletingLastPathComponent().path
        }
        return self
    }

    func addPathComponent(_ component: String) -> String
    {
        if let url = URL(string: self) {
            return url.appendingPathComponent(component).path
        }
        return self
    }
}
