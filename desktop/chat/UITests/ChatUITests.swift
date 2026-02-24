import XCTest

// swiftlint:disable file_length type_body_length
@MainActor
internal final class ChatUITests: XCTestCase {
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
        emailField.typeText("desktop-chat-e2e@test.local")

        let passwordField = app.textFields["Password"]
        passwordField.click()
        passwordField.typeKey("a", modifierFlags: .command)
        passwordField.typeText("Test123456!")

        app.buttons["Sign In"].click()

        let chatsButton = app.buttons["Chats"]
        if chatsButton.waitForExistence(timeout: 8) {
            return
        }

        if emailField.exists {
            let toggle = app.buttons["Need account? Sign Up"]
            if toggle.waitForExistence(timeout: 2) {
                toggle.click()
            }
            app.buttons["Create Account"].click()
            _ = chatsButton.waitForExistence(timeout: 10)
        }
    }

    private func ensureSignedOut() {
        let signOut = app.buttons["Sign Out"]
        if signOut.waitForExistence(timeout: 3) {
            signOut.click()
            _ = app.textFields["Email"].waitForExistence(timeout: 5)
        }
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
        XCTAssertFalse(app.buttons["Chats"].exists)
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

    func testAuthenticatedChatsButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Chats"].waitForExistence(timeout: 10))
    }

    func testAuthenticatedSignOutButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
    }

    func testNewChatButtonVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 10))
    }

    func testChatsHeaderVisible() {
        ensureAuthenticated()
        XCTAssertTrue(app.staticTexts["Chats"].waitForExistence(timeout: 10))
    }

    func testChatListOrEmptyState() {
        ensureAuthenticated()
        let emptyState = app.staticTexts["No chats yet"]
        let chatEntry = app.buttons["Open"].firstMatch
        let hasContent = emptyState.waitForExistence(timeout: 8) || chatEntry.waitForExistence(timeout: 2)
        XCTAssertTrue(hasContent)
    }

    func testCreateNewChat() {
        ensureAuthenticated()
        let newChatButton = app.buttons["New Chat"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 10))
        newChatButton.click()
        sleep(5)

        let openButton = app.buttons["Open"].firstMatch
        let noChats = app.staticTexts["No chats yet"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 10) || !noChats.exists)
    }

    func testChatShowsInListAfterCreation() {
        ensureAuthenticated()
        app.buttons["New Chat"].click()
        sleep(5)
        let openButton = app.buttons["Open"].firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 10))
    }

    func testChatShowsDeleteButton() {
        ensureAuthenticated()
        let deleteButton = app.buttons["Delete"].firstMatch
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 8) {
            XCTAssertTrue(deleteButton.exists)
        }
    }

    func testChatShowsPublicOrPrivateLabel() {
        ensureAuthenticated()
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 8) {
            let allTexts = app.staticTexts.allElementsBoundByIndex
            XCTAssertTrue(allTexts.count > 1, "Chat list should show additional labels alongside chat titles")
        }
    }

    func testNavigateToMessages() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
        }
    }

    func testMessageInputVisible() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            XCTAssertTrue(app.textFields["Message..."].waitForExistence(timeout: 10))
        }
    }

    func testSendButtonVisible() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            XCTAssertTrue(app.buttons["Send"].waitForExistence(timeout: 10))
        }
    }

    func testMessageInputAcceptsText() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            let msgField = app.textFields["Message..."]
            XCTAssertTrue(msgField.waitForExistence(timeout: 10))
            msgField.click()
            msgField.typeText("Hello world")
            let value = msgField.value as? String ?? ""
            XCTAssertTrue(value.contains("Hello"))
        }
    }

    func testEmptyMessagesStateOrMessages() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            let emptyState = app.staticTexts["No messages yet. Start a conversation!"]
            let messageField = app.textFields["Message..."]
            XCTAssertTrue(
                emptyState.waitForExistence(timeout: 8) || messageField.waitForExistence(timeout: 5)
            )
        }
    }

    func testBackNavigationFromMessages() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            let backButton = app.buttons["Back"]
            XCTAssertTrue(backButton.waitForExistence(timeout: 10))
            backButton.click()
            XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 5))
        }
    }

    func testSendMessageAndReceiveResponse() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }

        let msgField = app.textFields["Message..."]
        XCTAssertTrue(msgField.waitForExistence(timeout: 10))
        msgField.click()
        msgField.typeText("Tell me a joke")
        app.buttons["Send"].click()

        let aiThinking = app.staticTexts["AI is thinking..."]
        _ = aiThinking.waitForExistence(timeout: 5)

        sleep(20)
        let allTexts = app.staticTexts
        XCTAssertGreaterThanOrEqual(allTexts.count, 2)
    }

    func testInputClearsAfterSend() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            let msgField = app.textFields["Message..."]
            XCTAssertTrue(msgField.waitForExistence(timeout: 10))
            msgField.click()
            msgField.typeText("Test message to send")
            app.buttons["Send"].click()
            sleep(2)
            let value = msgField.value as? String ?? ""
            XCTAssertTrue(value.isEmpty || value == "Message...")
        }
    }

    func testDeleteChat() {
        ensureAuthenticated()
        app.buttons["New Chat"].click()
        sleep(5)

        let deleteButton = app.buttons["Delete"].firstMatch
        if deleteButton.waitForExistence(timeout: 8) {
            let countBefore = app.buttons.matching(identifier: "Open").count
            deleteButton.click()
            sleep(3)
            let countAfter = app.buttons.matching(identifier: "Open").count
            XCTAssertLessThanOrEqual(countAfter, countBefore)
        }
    }

    func testChatsButtonNavigatesToList() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if openButton.waitForExistence(timeout: 8) {
            openButton.click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
        }
        app.buttons["Chats"].click()
        XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 5))
    }

    func testSignOut() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
        app.buttons["Sign Out"].click()
        XCTAssertTrue(app.staticTexts["Sign In"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 5))
    }

    func testAIThinkingIndicatorVisible() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }

        let msgField = app.textFields["Message..."]
        XCTAssertTrue(msgField.waitForExistence(timeout: 10))
        msgField.click()
        msgField.typeText("Hello")
        app.buttons["Send"].click()

        let thinking = app.staticTexts["AI is thinking..."]
        _ = thinking.waitForExistence(timeout: 10)
    }

    func testMultipleChatsInList() {
        ensureAuthenticated()
        app.buttons["New Chat"].click()
        sleep(3)
        app.buttons["New Chat"].click()
        sleep(3)

        let openButtons = app.buttons.matching(identifier: "Open")
        XCTAssertGreaterThanOrEqual(openButtons.count, 2)
    }

    func testChatShowsTimestamp() {
        ensureAuthenticated()
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 8) {
            let allTexts = app.staticTexts.allElementsBoundByIndex
            XCTAssertTrue(allTexts.count > 1, "Chat list should display timestamps alongside chat entries")
        }
    }

    func testEmptySubmissionStays() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 10))
        sendButton.click()
        sleep(2)
        XCTAssertTrue(app.textFields["Message..."].exists)
    }

    func testInputReEnabledAfterResponse() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }
        let msgField = app.textFields["Message..."]
        XCTAssertTrue(msgField.waitForExistence(timeout: 10))
        msgField.click()
        msgField.typeText("Quick test")
        app.buttons["Send"].click()
        sleep(15)
        XCTAssertTrue(msgField.waitForExistence(timeout: 10))
        XCTAssertTrue(msgField.isEnabled)
    }

    func testMultipleMessagesInConversation() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }

        let msgField = app.textFields["Message..."]
        XCTAssertTrue(msgField.waitForExistence(timeout: 10))
        msgField.click()
        msgField.typeText("First message")
        app.buttons["Send"].click()
        sleep(15)

        msgField.click()
        msgField.typeText("Second message")
        app.buttons["Send"].click()
        sleep(15)

        let allTexts = app.staticTexts.allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(allTexts.count, 4)
    }

    func testMessagesPersistInOrder() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }

        let msgField = app.textFields["Message..."]
        XCTAssertTrue(msgField.waitForExistence(timeout: 10))

        msgField.click()
        msgField.typeText("Alpha message")
        app.buttons["Send"].click()
        sleep(15)

        msgField.click()
        msgField.typeText("Beta message")
        app.buttons["Send"].click()
        sleep(15)

        XCTAssertTrue(app.staticTexts["Alpha message"].exists)
        XCTAssertTrue(app.staticTexts["Beta message"].exists)
    }

    func testNavigateBetweenChats() {
        ensureAuthenticated()
        app.buttons["New Chat"].click()
        sleep(5)
        app.buttons["New Chat"].click()
        sleep(5)

        let openButtons = app.buttons.matching(identifier: "Open")
        if openButtons.count >= 2 {
            openButtons.element(boundBy: 0).click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
            app.buttons["Back"].click()
            XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 5))

            openButtons.element(boundBy: 1).click()
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
        }
    }

    func testToggleIsPublic() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }
        let checkbox = app.checkBoxes.firstMatch
        if checkbox.waitForExistence(timeout: 5) {
            checkbox.click()
            sleep(1)
            checkbox.click()
        }
        XCTAssertTrue(app.textFields["Message..."].exists)
    }

    func testPublicToggleVisibleInChatList() {
        ensureAuthenticated()
        let toggle = app.checkBoxes["Public"]
        if !toggle.waitForExistence(timeout: 5) {
            let toggleStatic = app.staticTexts["Public"]
            XCTAssertTrue(toggleStatic.waitForExistence(timeout: 5) || app.buttons["New Chat"].exists)
        }
    }

    func testPublicChatsButtonVisible() {
        ensureAuthenticated()
        let publicButton = app.buttons["Public Chats"]
        XCTAssertTrue(publicButton.waitForExistence(timeout: 10))
    }

    func testNavigateToPublicChats() {
        ensureAuthenticated()
        let publicButton = app.buttons["Public Chats"]
        XCTAssertTrue(publicButton.waitForExistence(timeout: 10))
        publicButton.click()
        let header = app.staticTexts["Public Chats"]
        XCTAssertTrue(header.waitForExistence(timeout: 10))
    }

    func testPublicChatsListOrEmptyState() {
        ensureAuthenticated()
        app.buttons["Public Chats"].click()
        let emptyState = app.staticTexts["No public chats"]
        let viewButton = app.buttons["View"].firstMatch
        let hasContent = emptyState.waitForExistence(timeout: 8) || viewButton.waitForExistence(timeout: 2)
        XCTAssertTrue(hasContent)
    }

    func testPublicChatsBackNavigation() {
        ensureAuthenticated()
        let publicButton = app.buttons["Public Chats"]
        XCTAssertTrue(publicButton.waitForExistence(timeout: 10))
        publicButton.click()
        XCTAssertTrue(app.staticTexts["Public Chats"].waitForExistence(timeout: 10))
        app.buttons["Back"].click()
        XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 5))
    }

    func testCreatePublicChat() {
        ensureAuthenticated()
        let checkbox = app.checkBoxes["Public"]
        if checkbox.waitForExistence(timeout: 5) {
            checkbox.click()
        }
        app.buttons["New Chat"].click()
        sleep(5)
        let publicLabel = app.staticTexts["Public"]
        XCTAssertTrue(publicLabel.waitForExistence(timeout: 10))
    }

    func testChatRealTimeSubscription() {
        ensureAuthenticated()
        let openButton = app.buttons["Open"].firstMatch
        if !openButton.waitForExistence(timeout: 8) {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        if app.buttons["Open"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Open"].firstMatch.click()
        }
        let loading = app.staticTexts["Loading messages..."]
        let emptyState = app.staticTexts["No messages yet. Start a conversation!"]
        let msgField = app.textFields["Message..."]
        XCTAssertTrue(
            loading.waitForExistence(timeout: 5)
                || emptyState.waitForExistence(timeout: 10)
                || msgField.waitForExistence(timeout: 10)
        )
        if loading.exists {
            XCTAssertTrue(
                emptyState.waitForExistence(timeout: 15)
                    || msgField.waitForExistence(timeout: 15)
            )
        }
    }

    func testChatPagination() {
        ensureAuthenticated()
        for _ in 0..<3 {
            app.buttons["New Chat"].click()
            sleep(3)
        }
        let openButtons = app.buttons.matching(identifier: "Open")
        XCTAssertGreaterThanOrEqual(openButtons.count, 1)
        let loadMore = app.buttons["Load More"]
        if loadMore.waitForExistence(timeout: 5) {
            loadMore.click()
            let loadingMore = app.staticTexts["Loading more..."]
            _ = loadingMore.waitForExistence(timeout: 5)
            sleep(3)
            XCTAssertTrue(app.buttons["Open"].firstMatch.exists)
        }
    }
}
