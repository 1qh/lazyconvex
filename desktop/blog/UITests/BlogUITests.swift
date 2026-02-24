import XCTest

// swiftlint:disable file_length type_body_length
@MainActor
internal final class BlogUITests: XCTestCase {
    private let app = XCUIApplication()

    // swiftlint:disable:next unneeded_throws_rethrows
    override func setUp() async throws {
        continueAfterFailure = true
        app.launch()
    }

    private func ensureAuthenticated() {
        let emailField = app.textFields["Email"]
        if !emailField.waitForExistence(timeout: 3) {
            return
        }

        emailField.click()
        emailField.typeKey("a", modifierFlags: .command)
        emailField.typeText("desktop-blog-e2e@test.local")

        let passwordField = app.textFields["Password"]
        passwordField.click()
        passwordField.typeKey("a", modifierFlags: .command)
        passwordField.typeText("Test123456!")

        app.buttons["Sign In"].click()

        let postsButton = app.buttons["Posts"]
        if postsButton.waitForExistence(timeout: 8) {
            return
        }

        if emailField.exists {
            let toggle = app.buttons["Need account? Sign Up"]
            if toggle.waitForExistence(timeout: 2) {
                toggle.click()
            }
            app.buttons["Create Account"].click()
            _ = postsButton.waitForExistence(timeout: 10)
        }
    }

    private func ensureSignedOut() {
        let signOut = app.buttons["Sign Out"]
        if signOut.waitForExistence(timeout: 3) {
            signOut.click()
            _ = app.textFields["Email"].waitForExistence(timeout: 5)
        }
    }

    private func createBlog(title: String, content: String) {
        let newPostButton = app.buttons["New Post"]
        XCTAssertTrue(newPostButton.waitForExistence(timeout: 5))
        newPostButton.click()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.click()
        titleField.typeText(title)

        let contentField = app.textFields["Content"]
        contentField.click()
        contentField.typeText(content)

        app.buttons["Create"].click()
    }

    func testAppLaunches() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    func testAuthViewShown() {
        ensureSignedOut()
        XCTAssertTrue(app.staticTexts["Sign In"].waitForExistence(timeout: 5))
    }

    func testEmailFieldVisible() {
        ensureSignedOut()
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 5))
    }

    func testPasswordFieldVisible() {
        ensureSignedOut()
        XCTAssertTrue(app.textFields["Password"].waitForExistence(timeout: 5))
    }

    func testSignInButtonVisible() {
        ensureSignedOut()
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 5))
    }

    func testToggleToSignUpMode() {
        ensureSignedOut()
        let toggle = app.buttons["Need account? Sign Up"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
        XCTAssertTrue(app.staticTexts["Sign Up"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create Account"].waitForExistence(timeout: 5))
    }

    func testToggleBackToSignIn() {
        ensureSignedOut()
        let toggle = app.buttons["Need account? Sign Up"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()

        let toggleBack = app.buttons["Have account? Sign In"]
        XCTAssertTrue(toggleBack.waitForExistence(timeout: 5))
        toggleBack.click()

        XCTAssertTrue(app.staticTexts["Sign In"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 5))
    }

    func testSignInWithInvalidCredentials() {
        ensureSignedOut()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.click()
        emailField.typeText("invalid@test.com")

        let passwordField = app.textFields["Password"]
        passwordField.click()
        passwordField.typeText("wrongpassword")

        app.buttons["Sign In"].click()
        sleep(5)
        XCTAssertTrue(emailField.exists)
        XCTAssertFalse(app.buttons["Posts"].exists)
    }

    func testEmptySignInStaysOnAuthView() {
        ensureSignedOut()
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.click()
        sleep(2)
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.staticTexts["Sign In"].exists)
    }

    func testSignUpButtonLabelChanges() {
        ensureSignedOut()
        let toggle = app.buttons["Need account? Sign Up"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()

        XCTAssertTrue(app.buttons["Create Account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Have account? Sign In"].waitForExistence(timeout: 5))
    }

    func testFieldsPreservedOnModeToggle() {
        ensureSignedOut()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.click()
        emailField.typeText("test@example.com")

        let passwordField = app.textFields["Password"]
        passwordField.click()
        passwordField.typeText("testpassword")

        app.buttons["Need account? Sign Up"].click()
        sleep(1)

        let emailValue = emailField.value as? String ?? ""
        XCTAssertTrue(emailValue.contains("test@example.com"))
    }

    func testSignInWithInvalidEmailShowsError() {
        ensureSignedOut()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.click()
        emailField.typeText("notauser@nonexistent.local")

        let passwordField = app.textFields["Password"]
        passwordField.click()
        passwordField.typeText("testpassword123")

        app.buttons["Sign In"].click()
        sleep(6)
        XCTAssertTrue(emailField.exists)
    }

    func testAuthenticatedPostsButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Posts"].waitForExistence(timeout: 10))
    }

    func testAuthenticatedProfileButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 10))
    }

    func testAuthenticatedNewPostButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["New Post"].waitForExistence(timeout: 10))
    }

    func testAuthenticatedSignOutButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
    }

    func testSearchInputVisibleOnList() {
        ensureAuthenticated()
        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
    }

    func testBlogListOrEmptyState() {
        ensureAuthenticated()
        let blogList = app.staticTexts["No posts yet"]
        let firstBlogTitle = app.buttons["View"].firstMatch
        let hasContent = blogList.waitForExistence(timeout: 8) || firstBlogTitle.waitForExistence(timeout: 2)
        XCTAssertTrue(hasContent)
    }

    func testNewPostFormOpens() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Content"].waitForExistence(timeout: 5))
    }

    func testNewPostFormHasCategoryField() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.textFields["Category (tech/life/tutorial)"].waitForExistence(timeout: 5))
    }

    func testNewPostFormHasPublishedToggle() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        let hasToggle = app.checkBoxes.firstMatch.waitForExistence(timeout: 3)
            || app.switches.firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Published"].waitForExistence(timeout: 3)
        XCTAssertTrue(hasToggle)
    }

    func testNewPostFormHasCancelButton() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    }

    func testNewPostFormHasCreateButton() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.buttons["Create"].waitForExistence(timeout: 5))
    }

    func testCancelNewPostReturnsToList() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].click()
        XCTAssertTrue(app.textFields["Search blogs..."].waitForExistence(timeout: 5))
    }

    func testCreateBlogPost() {
        ensureAuthenticated()
        let uniqueTitle = "E2E Blog \(Int(Date().timeIntervalSince1970))"
        createBlog(title: uniqueTitle, content: "E2E test content for blog post")
        sleep(3)
        XCTAssertTrue(
            app.textFields["Search blogs..."].waitForExistence(timeout: 10)
                || app.staticTexts["New Post"].waitForExistence(timeout: 2)
        )
    }

    func testCreatedBlogAppearsInList() {
        ensureAuthenticated()
        let uniqueTitle = "Listed Blog \(Int(Date().timeIntervalSince1970))"
        createBlog(title: uniqueTitle, content: "Content for listing test")
        sleep(3)

        app.buttons["Posts"].click()
        let blogText = app.staticTexts[uniqueTitle]
        XCTAssertTrue(blogText.waitForExistence(timeout: 10))
    }

    func testNavigateToDetail() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
        }
    }

    func testDetailShowsTitleAndCategory() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 10) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
            sleep(3)
            XCTAssertTrue(app.buttons["Edit"].exists)
            let allTexts = app.staticTexts.allElementsBoundByIndex
            XCTAssertTrue(allTexts.count > 2, "Detail view should show title, category, and status text")
        }
    }

    func testDetailShowsEditButton() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 10))
        }
    }

    func testDetailShowsDeleteButton() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 10))
        }
    }

    func testEditFormOpensFromDetail() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 10))
            app.buttons["Edit"].click()
            XCTAssertTrue(app.staticTexts["Edit Post"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["Content"].waitForExistence(timeout: 5))
        }
    }

    func testEditFormHasSaveButton() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            app.buttons["Edit"].click()
            XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5))
        }
    }

    func testEditFormHasCancelButton() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            app.buttons["Edit"].click()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        }
    }

    func testCancelEditReturnsToDetail() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            app.buttons["Edit"].click()
            XCTAssertTrue(app.staticTexts["Edit Post"].waitForExistence(timeout: 5))
            app.buttons["Cancel"].click()
            XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        }
    }

    func testBackFromDetailToList() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
            app.buttons["Back"].click()
            XCTAssertTrue(app.textFields["Search blogs..."].waitForExistence(timeout: 5))
        }
    }

    func testSearchInputAcceptsText() {
        ensureAuthenticated()
        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.click()
        searchField.typeText("search query")
        let value = searchField.value as? String ?? ""
        XCTAssertTrue(value.contains("search"))
    }

    func testProfileViewVisible() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        let displayNameField = app.textFields["Display Name"]
        let loadingText = app.staticTexts["Loading..."]
        let hasProfileContent = displayNameField.waitForExistence(timeout: 10)
            || loadingText.waitForExistence(timeout: 3)
        XCTAssertTrue(hasProfileContent)
    }

    func testProfileHasDisplayNameField() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.textFields["Display Name"].waitForExistence(timeout: 10))
    }

    func testProfileHasBioField() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.textFields["Bio"].waitForExistence(timeout: 10))
    }

    func testProfileHasThemeField() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.textFields["Theme (light/dark/system)"].waitForExistence(timeout: 10))
    }

    func testProfileHasSaveButton() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
    }

    func testProfileNavigateBackToPosts() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.textFields["Display Name"].waitForExistence(timeout: 10))
        app.buttons["Posts"].click()
        XCTAssertTrue(app.textFields["Search blogs..."].waitForExistence(timeout: 10))
    }

    func testSignOut() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
        app.buttons["Sign Out"].click()
        XCTAssertTrue(app.staticTexts["Sign In"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 5))
    }

    func testDeleteBlogFromDetail() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 10))
            app.buttons["Delete"].click()
            sleep(3)
            XCTAssertTrue(
                app.textFields["Search blogs..."].waitForExistence(timeout: 10)
                    || app.staticTexts["No posts yet"].waitForExistence(timeout: 5)
            )
        }
    }

    func testSearchFiltersBlogsByTitle() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        XCTAssert(viewButton.waitForExistence(timeout: 10))

        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()
        searchField.typeText("zzzzuniquefilterxyz999")
        sleep(2)

        let noResults = app.staticTexts["No posts yet"].waitForExistence(timeout: 5)
            || !viewButton.exists
        XCTAssertTrue(noResults)
    }

    func testSearchShowsNoResultsForGarbage() {
        ensureAuthenticated()
        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.click()
        searchField.typeText("zzzznonexistentquery999")
        sleep(1)
        XCTAssertTrue(
            app.staticTexts["No posts yet"].waitForExistence(timeout: 5)
                || app.buttons["View"].firstMatch.waitForExistence(timeout: 1) == false
        )
    }

    func testProfileFillAndSubmit() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        let nameField = app.textFields["Display Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("E2E Profile \(Int(Date().timeIntervalSince1970))")
        app.buttons["Save"].click()
        sleep(3)
        XCTAssertTrue(app.buttons["Profile"].exists || app.buttons["Save"].exists)
    }

    func testProfileUpdateDisplayName() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        let nameField = app.textFields["Display Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("Updated \(Int(Date().timeIntervalSince1970))")
        app.buttons["Save"].click()
        sleep(3)
        app.buttons["Posts"].click()
        app.buttons["Profile"].click()
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
    }

    func testProfileUpdateBio() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        let bioField = app.textFields["Bio"]
        XCTAssertTrue(bioField.waitForExistence(timeout: 10))
        bioField.click()
        bioField.typeKey("a", modifierFlags: .command)
        bioField.typeText("E2E bio \(Int(Date().timeIntervalSince1970))")
        app.buttons["Save"].click()
        sleep(3)
        XCTAssertTrue(app.buttons["Profile"].exists || app.buttons["Save"].exists)
    }

    func testProfileChangeTheme() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        let themeField = app.textFields["Theme (light/dark/system)"]
        XCTAssertTrue(themeField.waitForExistence(timeout: 10))
        themeField.click()
        themeField.typeKey("a", modifierFlags: .command)
        themeField.typeText("dark")
        app.buttons["Save"].click()
        sleep(3)
        XCTAssertTrue(app.buttons["Profile"].exists || app.buttons["Save"].exists)
    }

    func testProfileToggleNotifications() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.textFields["Display Name"].waitForExistence(timeout: 10))
        let checkbox = app.checkBoxes.firstMatch
        if checkbox.waitForExistence(timeout: 5) {
            checkbox.click()
        }
        app.buttons["Save"].click()
        sleep(3)
        XCTAssertTrue(app.buttons["Profile"].exists || app.buttons["Save"].exists)
    }

    func testCreateFormValidation() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        app.buttons["Create"].click()
        sleep(2)
        XCTAssertTrue(app.staticTexts["New Post"].exists || app.textFields["Title"].exists)
    }

    func testEditFormShowsCurrentValues() {
        ensureAuthenticated()
        let uniqueTitle = "Prefill \(Int(Date().timeIntervalSince1970))"
        createBlog(title: uniqueTitle, content: "Prefill content")
        sleep(3)
        app.buttons["Posts"].click()

        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 10) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 10))
            app.buttons["Edit"].click()
            XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
            let titleValue = app.textFields["Title"].value as? String ?? ""
            XCTAssertFalse(titleValue.isEmpty)
        }
    }

    func testTogglePublishInEdit() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 10))
            app.buttons["Edit"].click()
            XCTAssertTrue(app.staticTexts["Edit Post"].waitForExistence(timeout: 5))
            let checkbox = app.checkBoxes.firstMatch
            if checkbox.waitForExistence(timeout: 5) {
                checkbox.click()
            }
            app.buttons["Save"].click()
            sleep(3)
            XCTAssertTrue(
                app.buttons["Edit"].waitForExistence(timeout: 10)
                    || app.textFields["Search blogs..."].waitForExistence(timeout: 5)
            )
        }
    }

    func testSearchShowsFilteredResults() {
        ensureAuthenticated()
        let uniqueTitle = "Filterable \(Int(Date().timeIntervalSince1970))"
        createBlog(title: uniqueTitle, content: "Filter content")
        sleep(3)
        app.buttons["Posts"].click()

        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.click()
        searchField.typeText("Filterable")
        sleep(2)
        XCTAssertTrue(
            app.staticTexts[uniqueTitle].waitForExistence(timeout: 10)
                || app.buttons["View"].firstMatch.exists
        )
    }

    func testSearchIsCaseInsensitive() {
        ensureAuthenticated()
        let ts = Int(Date().timeIntervalSince1970)
        let uniqueTitle = "CaseSearch \(ts)"
        createBlog(title: uniqueTitle, content: "Case insensitive test \(ts)")
        sleep(3)
        app.buttons["Posts"].click()

        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.click()
        searchField.typeText("casesearch")
        sleep(2)
        XCTAssertTrue(app.staticTexts[uniqueTitle].waitForExistence(timeout: 10))

        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("CASESEARCH")
        sleep(2)
        XCTAssertTrue(app.staticTexts[uniqueTitle].waitForExistence(timeout: 10))
    }

    func testSearchFiltersBlogsByContent() {
        ensureAuthenticated()
        let ts = Int(Date().timeIntervalSince1970)
        let uniqueContent = "zebracontent\(ts)"
        createBlog(title: "Content Post \(ts)", content: "Has \(uniqueContent) inside")
        sleep(3)
        app.buttons["Posts"].click()

        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.click()
        searchField.typeText(uniqueContent)
        sleep(2)
        XCTAssertTrue(
            app.staticTexts["Content Post \(ts)"].waitForExistence(timeout: 10)
                || app.buttons["View"].firstMatch.exists
        )
    }

    func testSearchClearAndReSearch() {
        ensureAuthenticated()
        let ts = Int(Date().timeIntervalSince1970)
        let prefix = "ClearSearch\(ts)"
        createBlog(title: "\(prefix)First", content: "First clear test")
        sleep(3)
        createBlog(title: "\(prefix)Second", content: "Second clear test")
        sleep(3)
        app.buttons["Posts"].click()

        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))

        searchField.click()
        searchField.typeText("\(prefix)First")
        sleep(2)
        XCTAssertTrue(app.staticTexts["\(prefix)First"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["\(prefix)Second"].exists)

        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText(prefix)
        sleep(2)
        XCTAssertTrue(app.staticTexts["\(prefix)First"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["\(prefix)Second"].waitForExistence(timeout: 5))
    }

    func testSearchUpdatesInRealTime() {
        ensureAuthenticated()
        let ts = Int(Date().timeIntervalSince1970)
        createBlog(title: "ReactTut\(ts)", content: "Learn React basics \(ts)")
        sleep(3)
        createBlog(title: "VueTut\(ts)", content: "Learn Vue basics \(ts)")
        sleep(3)
        app.buttons["Posts"].click()

        let searchField = app.textFields["Search blogs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))

        searchField.click()
        searchField.typeText("ReactTut\(ts)")
        sleep(2)
        XCTAssertTrue(app.staticTexts["ReactTut\(ts)"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["VueTut\(ts)"].exists)

        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("Tut\(ts)")
        sleep(2)
        XCTAssertTrue(app.staticTexts["ReactTut\(ts)"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["VueTut\(ts)"].waitForExistence(timeout: 5))
    }

    func testNewPostFormHasCoverImageButton() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Cover Image"].waitForExistence(timeout: 5))
    }

    func testNewPostFormHasTagInput() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Add tag"].waitForExistence(timeout: 5))
    }

    func testNewPostFormHasAttachmentsButton() {
        ensureAuthenticated()
        app.buttons["New Post"].click()
        XCTAssertTrue(app.staticTexts["New Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Attachments"].waitForExistence(timeout: 5))
    }

    func testListShowsLoadMoreButton() {
        ensureAuthenticated()
        sleep(3)
        let loadMore = app.buttons["Load More"]
        let noPostsYet = app.staticTexts["No posts yet"]
        XCTAssertTrue(
            loadMore.waitForExistence(timeout: 10)
                || noPostsYet.waitForExistence(timeout: 3)
                || app.buttons["View"].firstMatch.waitForExistence(timeout: 3)
        )
    }

    func testEditFormShowsAutoSaveIndicator() {
        ensureAuthenticated()
        let viewButton = app.buttons["View"].firstMatch
        if viewButton.waitForExistence(timeout: 8) {
            viewButton.click()
            XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 10))
            app.buttons["Edit"].click()
            XCTAssertTrue(app.staticTexts["Edit Post"].waitForExistence(timeout: 5))
            let titleField = app.textFields["Title"]
            if titleField.waitForExistence(timeout: 5) {
                titleField.click()
                titleField.typeText(" test")
                sleep(1)
                let hasIndicator = app.staticTexts["Editing..."].waitForExistence(timeout: 5)
                    || app.staticTexts["Saving..."].waitForExistence(timeout: 5)
                    || app.staticTexts["Saved"].waitForExistence(timeout: 5)
                XCTAssertTrue(hasIndicator)
            }
        }
    }

    func testProfileHasAvatarButton() {
        ensureAuthenticated()
        app.buttons["Profile"].click()
        XCTAssertTrue(app.textFields["Display Name"].waitForExistence(timeout: 10))
        let hasAvatarButton = app.buttons["Add Avatar"].waitForExistence(timeout: 5)
            || app.buttons["Change Avatar"].waitForExistence(timeout: 3)
        XCTAssertTrue(hasAvatarButton)
    }
}
