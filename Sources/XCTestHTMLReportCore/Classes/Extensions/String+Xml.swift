//
//  String+Xml.swift
//  XCTestHTMLReport
//
//  Created by Taisuke HORI on 2018/10/16.
//  Copyright © 2018 Tito. All rights reserved.
//

extension String {
    var stringByEscapingXMLChars: String {
        return replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
