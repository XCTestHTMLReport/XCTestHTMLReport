//
//  Array+ConcurrentMap.swift
//  XCTestHTMLReport
//
//  Created by Evan Coleman on 9/1/20.
//

import Foundation

extension Array {
    func concurrentMap<B>(_ transform: @escaping (Element) -> B) -> [B] {
        var result = Array<B?>(repeating: nil, count: count)
        let q = DispatchQueue(label: "sync queue")
        DispatchQueue.concurrentPerform(iterations: count) { idx in
            let element = self[idx]
            let transformed = transform(element)
            q.sync {
                result[idx] = transformed
            }
        }
        return result.map { $0! }
    }

    func concurrentCompactMap<B>(_ transform: @escaping (Element) -> B?) -> [B] {
        return concurrentMap(transform).compactMap { $0 }
    }
}
