//
//  TestSupportNDHppleElement.swift
//
//
//  Created by Guillermo Ignacio Enriquez Gutierrez on 2021/01/18.
//

import Foundation

import NDHpple

extension NDHppleElement {
    func rawValueOfAttribute(name: String) -> String? {
        return attributes[name]?["rawValue"] as? String
    }
}
