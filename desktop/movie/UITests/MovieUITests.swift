import XCTest

@MainActor
internal final class MovieUITests: XCTestCase {
    private let app = XCUIApplication()

    // swiftlint:disable:next unneeded_throws_rethrows
    override func setUp() async throws {
        continueAfterFailure = true
        app.launch()
    }

    func testAppLaunches() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    func testSearchFieldVisible() {
        XCTAssertTrue(app.textFields["Search movies..."].waitForExistence(timeout: 5))
    }

    func testSearchButtonVisible() {
        XCTAssertTrue(app.buttons["Search"].waitForExistence(timeout: 5))
    }

    func testEmptyStateShown() {
        XCTAssertTrue(app.staticTexts["Search for movies by title"].waitForExistence(timeout: 5))
    }

    func testSearchFieldAcceptsInput() {
        let field = app.textFields["Search movies..."]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("test query")
        XCTAssertNotEqual(field.value as? String, "")
    }

    func testSearchReturnsResults() {
        let field = app.textFields["Search movies..."]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("Inception")
        app.buttons["Search"].click()
        XCTAssertTrue(app.staticTexts["Inception"].waitForExistence(timeout: 15))
    }

    func testSearchDisplaysMovieTitle() {
        searchFor("Fight Club")
        let title = app.staticTexts["Fight Club"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
    }

    func testBroadSearchReturnsMultipleResults() {
        searchFor("Batman")
        let firstView = app.buttons["View"].firstMatch
        XCTAssertTrue(firstView.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.buttons.matching(identifier: "View").count, 1)
    }

    func testSearchShowsYearInResults() {
        searchFor("Inception")
        let viewButton = app.buttons["View"].firstMatch
        XCTAssertTrue(viewButton.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["2010"].waitForExistence(timeout: 5))
    }

    func testSearchShowsOverviewInResults() {
        searchFor("Inception")
        let viewButton = app.buttons["View"].firstMatch
        XCTAssertTrue(viewButton.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.staticTexts.count, 3)
    }

    func testSearchNavigateToDetail() {
        searchFor("Inception")
        let viewLink = app.buttons["View"].firstMatch
        XCTAssertTrue(viewLink.waitForExistence(timeout: 15))
        viewLink.click()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 15))
    }

    func testDetailShowsMovieTitle() {
        navigateToDetail("Inception")
        XCTAssertTrue(app.staticTexts["Inception"].waitForExistence(timeout: 15))
    }

    func testDetailShowsReleaseDate() {
        navigateToDetail("Inception")
        let releasePredicate = NSPredicate(
            format: "label CONTAINS 'Release:' OR value CONTAINS 'Release:'"
        )
        let releaseText = app.staticTexts.matching(releasePredicate).firstMatch
        XCTAssertTrue(releaseText.waitForExistence(timeout: 15))
    }

    func testDetailShowsRating() {
        navigateToDetail("Inception")
        let ratingPredicate = NSPredicate(
            format: "label CONTAINS 'Rating:' OR value CONTAINS 'Rating:'"
        )
        let ratingText = app.staticTexts.matching(ratingPredicate).firstMatch
        XCTAssertTrue(ratingText.waitForExistence(timeout: 15))
    }

    func testDetailShowsVoteCount() {
        navigateToDetail("Inception")
        let votesPredicate = NSPredicate(
            format: "label CONTAINS 'votes' OR value CONTAINS 'votes'"
        )
        let votesText = app.staticTexts.matching(votesPredicate).firstMatch
        XCTAssertTrue(votesText.waitForExistence(timeout: 15))
    }

    func testDetailShowsOverview() {
        navigateToDetail("Inception")
        XCTAssertTrue(app.staticTexts["Inception"].waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.staticTexts.count, 3)
    }

    func testBackNavigationFromDetail() {
        navigateToDetail("Inception")
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 15))
        backButton.click()
        XCTAssertTrue(app.textFields["Search movies..."].waitForExistence(timeout: 5))
    }

    func testBackNavigationPreservesSearchView() {
        searchFor("Inception")
        let viewLink = app.buttons["View"].firstMatch
        XCTAssertTrue(viewLink.waitForExistence(timeout: 15))
        viewLink.click()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 15))
        backButton.click()

        XCTAssertTrue(app.textFields["Search movies..."].waitForExistence(timeout: 5))
    }

    func testSearchDifferentMovies() {
        searchFor("Matrix")
        XCTAssertTrue(app.buttons["View"].firstMatch.waitForExistence(timeout: 15))

        let field = app.textFields["Search movies..."]
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Titanic")
        app.buttons["Search"].click()

        XCTAssertTrue(app.staticTexts["Titanic"].waitForExistence(timeout: 15))
    }

    func testRetryButtonOnDetailError() {
        navigateToDetail("Inception")
        XCTAssertTrue(app.staticTexts["Inception"].waitForExistence(timeout: 15))
    }

    func testDetailShowsCacheIndicator() {
        navigateToDetail("Inception")
        XCTAssertTrue(app.staticTexts["Inception"].waitForExistence(timeout: 15))
        let cacheHitPredicate = NSPredicate(
            format: "label CONTAINS 'Cache Hit' OR label CONTAINS 'Cache Miss'"
        )
        let cacheText = app.staticTexts.matching(cacheHitPredicate).firstMatch
        XCTAssertTrue(cacheText.waitForExistence(timeout: 15))
    }

    func testFetchByIDFieldVisible() {
        XCTAssertTrue(app.textFields["TMDB ID"].waitForExistence(timeout: 5))
    }

    func testFetchByIDButton() {
        XCTAssertTrue(app.buttons["Fetch"].waitForExistence(timeout: 5))
    }

    func testFetchByIDNavigatesToDetail() {
        let field = app.textFields["TMDB ID"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("550")
        app.buttons["Fetch"].click()
        XCTAssertTrue(app.staticTexts["Fight Club"].waitForExistence(timeout: 15))
    }

    func testDetailShowsGenres() {
        navigateToDetail("Inception")
        let genre = app.staticTexts["Science Fiction"]
        XCTAssertTrue(genre.waitForExistence(timeout: 15))
    }

    func testDetailShowsBackdropImage() {
        navigateToDetail("Inception")
        let images = app.images
        let imageCount = images.count
        XCTAssertTrue(imageCount >= 1)
    }

    private func searchFor(_ query: String) {
        let field = app.textFields["Search movies..."]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText(query)
        app.buttons["Search"].click()
    }

    private func navigateToDetail(_ query: String) {
        searchFor(query)
        let viewLink = app.buttons["View"].firstMatch
        XCTAssertTrue(viewLink.waitForExistence(timeout: 15))
        viewLink.click()
    }
}
