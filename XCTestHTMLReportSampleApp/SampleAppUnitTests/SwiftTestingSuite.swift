//
//  SwiftTestingSuite.swift
//  SampleAppUnitTests
//
//  Added to investigate XCTestHTMLReport's support for Swift Testing
//  results (`import Testing`) as part of #393.
//

import Testing

struct SwiftTestingSuite {
    @Test func additionWorks() {
        #expect(1 + 1 == 2)
    }

    @Test func intentionalFailure() {
        #expect(false, "This Swift Testing test intentionally fails")
    }

    @Test("Tagged multiplication check", .tags(.sampleTag))
    func taggedMultiplication() {
        #expect(2 * 3 == 6)
    }
}

extension Tag {
    @Tag static var sampleTag: Tag
}
