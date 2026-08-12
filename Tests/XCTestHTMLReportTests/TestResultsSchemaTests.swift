//
//  TestResultsSchemaTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class TestResultsSchemaTests: XCTestCase {
    func testDecodesRepetitionNodes() throws {
        let json = """
        {"testNodes":[{"name":"MainScheme","nodeType":"Test Plan","result":"Failed",
        "children":[{"name":"testRetryOnFailure()","nodeType":"Test Case",
        "nodeIdentifier":"RetryTests/testRetryOnFailure()","result":"Passed",
        "durationInSeconds":0.068,"children":[
        {"name":"First Run","nodeType":"Repetition","nodeIdentifier":"1","result":"Failed",
        "durationInSeconds":0.078},
        {"name":"Retry 1","nodeType":"Repetition","nodeIdentifier":"2","result":"Passed",
        "durationInSeconds":0.059}]}]}],
        "devices":[],"testPlanConfigurations":[]}
        """
        let decoded = try JSONDecoder().decode(
            TestResultsTests.self, from: Data(json.utf8)
        )
        let testCase = try XCTUnwrap(decoded.testNodes?.first?.children?.first)
        XCTAssertEqual(testCase.nodeType, "Test Case")
        XCTAssertEqual(testCase.children?.count, 2)
        XCTAssertEqual(testCase.children?.map(\.nodeIdentifier), ["1", "2"])
    }

    func testDecodesArgumentsNodes() throws {
        // Shape taken from the published schema (`get test-results tests
        // --schema` lists `Arguments`, `Expression` and `Test Value` in
        // `TestNodeType`), not from a fixture: no fixture produces an
        // `Arguments` node yet. See the design doc's answer 6.
        let json = """
        {"testNodes":[{"name":"multiplication(factor:)","nodeType":"Test Case",
        "result":"Passed","children":[
        {"name":"Arguments: 2","nodeType":"Arguments","result":"Passed","children":[
        {"name":"factor → 2","nodeType":"Test Value","result":"Passed"}]}]}],
        "devices":[],"testPlanConfigurations":[]}
        """
        let decoded = try JSONDecoder().decode(
            TestResultsTests.self, from: Data(json.utf8)
        )
        let arguments = try XCTUnwrap(decoded.testNodes?.first?.children?.first)
        XCTAssertEqual(arguments.nodeType, "Arguments")
        XCTAssertEqual(arguments.children?.first?.nodeType, "Test Value")
    }

    func testDecodesActivityAttachments() throws {
        let json = """
        {"testIdentifier":"FirstSuite/testTwo()","testName":"testTwo()","testRuns":[
        {"activities":[{"title":"Start Test","startTime":1786425364.793,
        "isAssociatedWithFailure":false,"attachments":[
        {"name":"Screen Recording.mp4","payloadId":"0~abc",
        "uuid":"4DB9AD3F-E485-4F77-9771-8FAC7270E261","timestamp":1786425364.806,
        "lifetime":"deleteOnSuccess"}]}]}]}
        """
        let decoded = try JSONDecoder().decode(TestActivities.self, from: Data(json.utf8))
        let attachment = try XCTUnwrap(
            decoded.testRuns?.first?.activities?.first?.attachments?.first
        )
        XCTAssertEqual(attachment.uuid, "4DB9AD3F-E485-4F77-9771-8FAC7270E261")
        XCTAssertEqual(attachment.name, "Screen Recording.mp4")
    }
}
