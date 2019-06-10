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
        return (self as NSString).deletingLastPathComponent
    }

    func relativePath(from basePath: String) -> String {
        let basePathComponents = (basePath as NSString).pathComponents
        var pathComponents = (self as NSString).pathComponents

        var offset = 0
        for (index, element) in basePathComponents.enumerated() {
            guard index < pathComponents.count, element == pathComponents[index] else { break }
            offset += 1
        }

        pathComponents.removeFirst(offset)
        pathComponents.insert(
            contentsOf: Array(repeating: "..", count: basePathComponents.count - offset),
            at: 0
        )

        return NSString.path(withComponents: pathComponents)
    }
}
