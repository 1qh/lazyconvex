import Foundation
@testable import Movie
import OSLog
import XCTest

internal let logger = Logger(subsystem: "Movie", category: "Tests")

@available(macOS 13, *)
internal final class AppTests: XCTestCase {
    func testApp() {
        logger.log("running testApp")
        XCTAssertEqual(1 + 2, 3, "basic test")
    }

    func testDecodeType() throws {
        let resourceURL: URL = try XCTUnwrap(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        XCTAssertEqual("Movie", testData.testModuleName)
    }
}

internal struct TestData: Codable, Hashable {
    var testModuleName: String
}
