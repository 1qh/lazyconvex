import Foundation
@testable import Org
import OSLog
import XCTest

internal let logger = Logger(subsystem: "Org", category: "Tests")

@available(macOS 13, *)
internal final class AppTests: XCTestCase {
    func testApp() {
        logger.log("running testApp")
        XCTAssertEqual(1 + 2, 3, "basic test")
    }

    func testDecodeType() throws {
        let resourceURL: URL = try XCTUnwrap(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        XCTAssertEqual("Org", testData.testModuleName)
    }
}

internal struct TestData: Codable, Hashable {
    var testModuleName: String
}
