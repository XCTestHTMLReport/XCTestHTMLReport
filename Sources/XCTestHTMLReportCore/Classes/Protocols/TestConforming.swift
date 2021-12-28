//
//  File.swift
//
//
//  Created by Tyler Vick on 12/28/21.
//

import Foundation

protocol Test: HTML, ContainingAttachment {
    var uuid: String { get }
    var title: String { get }
    var identifier: String { get }
    var objectClass: ObjectClass { get }
    var status: Status { get }
    var duration: TimeInterval { get }
}
