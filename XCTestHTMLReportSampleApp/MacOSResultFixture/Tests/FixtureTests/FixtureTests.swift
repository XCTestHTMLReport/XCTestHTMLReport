@testable import Fixture
import XCTest

final class FixtureTests: XCTestCase {
    func testFixtureValue() {
        XCTAssertEqual(fixtureValue(), 42)
    }
}
