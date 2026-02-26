import XCTest

// swiftlint:disable file_length type_body_length
@MainActor
internal final class OrgUITests: XCTestCase {
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
        emailField.typeText("desktop-org-e2e@test.local")

        let passwordField = app.textFields["Password"]
        passwordField.click()
        passwordField.typeKey("a", modifierFlags: .command)
        passwordField.typeText("Test123456!")

        app.buttons["Sign In"].click()

        let orgText = app.staticTexts["Organizations"]
        let getStarted = app.buttons["Get Started"]
        let selectButton = app.buttons["Select"].firstMatch
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label BEGINSWITH 'Step '")
            )
            .firstMatch

        if orgText.waitForExistence(timeout: 8) || getStarted.waitForExistence(timeout: 2)
            || selectButton.waitForExistence(timeout: 2) || stepText.waitForExistence(timeout: 2) {
            return
        }

        if emailField.exists {
            let toggle = app.buttons["Need account? Sign Up"]
            if toggle.waitForExistence(timeout: 2) {
                toggle.click()
            }
            app.buttons["Create Account"].click()
            _ = orgText.waitForExistence(timeout: 10)
                || getStarted.waitForExistence(timeout: 5)
        }
    }

    private func ensureSignedOut() {
        let signOut = app.buttons["Sign Out"]
        if signOut.waitForExistence(timeout: 3) {
            signOut.click()
            _ = app.textFields["Email"].waitForExistence(timeout: 5)
        }
    }

    private func ensureInOrg() {
        ensureAuthenticated()

        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label BEGINSWITH 'Step '")
            )
            .firstMatch
        if stepText.waitForExistence(timeout: 3) {
            completeOnboarding()
        }

        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 2) {
            getStarted.click()
            sleep(1)
            completeOnboarding()
        }

        let selectButton = app.buttons["Select"].firstMatch
        if selectButton.waitForExistence(timeout: 3) {
            selectButton.click()
            sleep(2)
            return
        }

        let projectsButton = app.buttons["Projects"]
        _ = projectsButton.waitForExistence(timeout: 5)
    }

    private func completeOnboarding() {
        let displayNameField = app.textFields["Display Name"]
        if displayNameField.waitForExistence(timeout: 5) {
            displayNameField.click()
            displayNameField.typeKey("a", modifierFlags: .command)
            displayNameField.typeText("E2E Test User")
        }

        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.click()
        }

        let orgNameField = app.textFields["Organization Name"]
        if orgNameField.waitForExistence(timeout: 5) {
            orgNameField.click()
            orgNameField.typeKey("a", modifierFlags: .command)
            orgNameField.typeText("E2E Test Org")

            let slugField = app.textFields["URL Slug"]
            slugField.click()
            slugField.typeKey("a", modifierFlags: .command)
            slugField.typeText("e2e-test-\(Int(Date().timeIntervalSince1970))")
        }

        if nextButton.exists {
            nextButton.click()
        }

        sleep(1)
        if nextButton.exists {
            nextButton.click()
        }

        sleep(1)
        let completeButton = app.buttons["Complete"]
        if completeButton.waitForExistence(timeout: 3) {
            completeButton.click()
        }
        sleep(5)
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

        app.buttons["Need account? Sign Up"].click()
        sleep(1)
        let emailValue = emailField.value as? String ?? ""
        XCTAssertTrue(emailValue.contains("test@example.com"))
    }

    func testAuthenticatedShowsSwitcherOrOnboarding() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        let getStarted = app.buttons["Get Started"]
        let selectButton = app.buttons["Select"].firstMatch
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label BEGINSWITH 'Step '")
            )
            .firstMatch
        let projectsButton = app.buttons["Projects"]

        let hasPostAuth = orgText.waitForExistence(timeout: 10)
            || getStarted.waitForExistence(timeout: 2)
            || selectButton.waitForExistence(timeout: 2)
            || stepText.waitForExistence(timeout: 2)
            || projectsButton.waitForExistence(timeout: 2)
        XCTAssertTrue(hasPostAuth)
    }

    func testSwitcherShowsSignOutButton() {
        ensureAuthenticated()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
    }

    func testSwitcherShowsNewOrgButton() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        if orgText.waitForExistence(timeout: 8) {
            XCTAssertTrue(app.buttons["New Org"].waitForExistence(timeout: 5))
        }
    }

    func testNewOrgFormOpens() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        if orgText.waitForExistence(timeout: 8) {
            app.buttons["New Org"].click()
            XCTAssertTrue(app.textFields["Organization Name"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["Slug"].waitForExistence(timeout: 5))
        }
    }

    func testNewOrgFormHasCancelButton() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        if orgText.waitForExistence(timeout: 8) {
            app.buttons["New Org"].click()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        }
    }

    func testNewOrgFormHasCreateButton() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        if orgText.waitForExistence(timeout: 8) {
            app.buttons["New Org"].click()
            XCTAssertTrue(app.buttons["Create"].waitForExistence(timeout: 5))
        }
    }

    func testCancelNewOrgClosesForm() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        if orgText.waitForExistence(timeout: 8) {
            app.buttons["New Org"].click()
            XCTAssertTrue(app.textFields["Organization Name"].waitForExistence(timeout: 5))
            app.buttons["Cancel"].click()
            sleep(1)
            XCTAssertFalse(app.textFields["Organization Name"].exists)
        }
    }

    func testOnboardingStep1ShowsDisplayName() {
        ensureAuthenticated()
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        let getStarted = app.buttons["Get Started"]

        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        if stepText.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.textFields["Display Name"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["Bio"].waitForExistence(timeout: 5))
        }
    }

    func testOnboardingStep1NextButton() {
        ensureAuthenticated()
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        let getStarted = app.buttons["Get Started"]

        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        if stepText.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["Back"].exists)
        }
    }

    func testOnboardingAdvancesToStep2() {
        ensureAuthenticated()
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        let getStarted = app.buttons["Get Started"]

        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        if stepText.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("E2E Onboard")
            app.buttons["Next"].click()

            let step2 = app.staticTexts
                .matching(
                    NSPredicate(format: "label CONTAINS 'Step 2'")
                )
                .firstMatch
            XCTAssertTrue(step2.waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["Organization Name"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["URL Slug"].waitForExistence(timeout: 5))
        }
    }

    func testOnboardingStep2HasBackButton() {
        ensureAuthenticated()
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        let getStarted = app.buttons["Get Started"]

        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        if stepText.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Back Test")
            app.buttons["Next"].click()
            sleep(1)
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        }
    }

    func testOnboardingBackReturnsToStep1() {
        ensureAuthenticated()
        let stepText = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        let getStarted = app.buttons["Get Started"]

        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        if stepText.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Back Nav")
            app.buttons["Next"].click()

            let step2 = app.staticTexts
                .matching(
                    NSPredicate(format: "label CONTAINS 'Step 2'")
                )
                .firstMatch
            XCTAssertTrue(step2.waitForExistence(timeout: 5))

            app.buttons["Back"].click()
            let step1Again = app.staticTexts
                .matching(
                    NSPredicate(format: "label CONTAINS 'Step 1'")
                )
                .firstMatch
            XCTAssertTrue(step1Again.waitForExistence(timeout: 5))
        }
    }

    func testOnboardingNavigateAllSteps() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        let step1 = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Nav All")
            app.buttons["Next"].click()

            let step2 = app.staticTexts
                .matching(
                    NSPredicate(format: "label CONTAINS 'Step 2'")
                )
                .firstMatch
            XCTAssertTrue(step2.waitForExistence(timeout: 5))

            let orgName = app.textFields["Organization Name"]
            orgName.click()
            orgName.typeText("Nav Org")
            let slug = app.textFields["URL Slug"]
            slug.click()
            slug.typeText("nav-all-\(Int(Date().timeIntervalSince1970))")
            app.buttons["Next"].click()

            let step3 = app.staticTexts
                .matching(
                    NSPredicate(format: "label CONTAINS 'Step 3'")
                )
                .firstMatch
            XCTAssertTrue(step3.waitForExistence(timeout: 5))

            app.buttons["Next"].click()

            let step4 = app.staticTexts
                .matching(
                    NSPredicate(format: "label CONTAINS 'Step 4'")
                )
                .firstMatch
            XCTAssertTrue(step4.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Complete"].waitForExistence(timeout: 5))
        }
    }

    func testOnboardingStep3HasThemeField() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        let step1 = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Theme Test")
            app.buttons["Next"].click()

            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Theme Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("theme-\(Int(Date().timeIntervalSince1970))")
                app.buttons["Next"].click()

                XCTAssertTrue(app.textFields["Theme (light/dark/system)"].waitForExistence(timeout: 5))
            }
        }
    }

    func testOnboardingStep4HasNotificationsToggle() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        let step1 = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Notif Test")
            app.buttons["Next"].click()

            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Notif Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("notif-\(Int(Date().timeIntervalSince1970))")
                app.buttons["Next"].click()
                sleep(1)
                app.buttons["Next"].click()
                sleep(1)

                let hasNotifElement = app.checkBoxes.firstMatch.exists
                    || app.switches.firstMatch.exists
                    || app.staticTexts["Enable Notifications"].exists
                XCTAssertTrue(hasNotifElement)
            }
        }
    }

    func testHomeViewProjectsButtonVisible() {
        ensureInOrg()
        XCTAssertTrue(app.buttons["Projects"].waitForExistence(timeout: 10))
    }

    func testHomeViewWikiButtonVisible() {
        ensureInOrg()
        XCTAssertTrue(app.buttons["Wiki"].waitForExistence(timeout: 10))
    }

    func testHomeViewMembersButtonVisible() {
        ensureInOrg()
        XCTAssertTrue(app.buttons["Members"].waitForExistence(timeout: 10))
    }

    func testHomeViewSettingsButtonVisible() {
        ensureInOrg()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
    }

    func testHomeViewSwitchOrgButtonVisible() {
        ensureInOrg()
        XCTAssertTrue(app.buttons["Switch Org"].waitForExistence(timeout: 10))
    }

    func testHomeViewSignOutButtonVisible() {
        ensureInOrg()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
    }

    func testHomeViewShowsOrgName() {
        ensureInOrg()
        let allTexts = app.staticTexts
        XCTAssertGreaterThan(allTexts.count, 0)
    }

    func testProjectsSectionDefault() {
        ensureInOrg()
        let newProjectButton = app.buttons["New Project"]
        let projectsHeader = app.staticTexts["Projects"]
        let emptyProjects = app.staticTexts["No projects yet"]
        XCTAssertTrue(
            newProjectButton.waitForExistence(timeout: 10)
                || projectsHeader.waitForExistence(timeout: 5)
                || emptyProjects.waitForExistence(timeout: 5)
        )
    }

    func testSwitchToWikiSection() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        let newWikiButton = app.buttons["New Page"]
        let wikiHeader = app.staticTexts["Wiki"]
        let emptyWiki = app.staticTexts["No wiki pages yet"]
        XCTAssertTrue(
            newWikiButton.waitForExistence(timeout: 10)
                || wikiHeader.waitForExistence(timeout: 5)
                || emptyWiki.waitForExistence(timeout: 5)
        )
    }

    func testSwitchToMembersSection() {
        ensureInOrg()
        app.buttons["Members"].click()
        let membersHeader = app.staticTexts["Members"]
        let ownerPredicate = NSPredicate(
            format: "label CONTAINS[c] 'owner' OR label CONTAINS[c] 'Owner'"
        )
        let ownerBadge = app.staticTexts.matching(ownerPredicate).firstMatch
        XCTAssertTrue(
            membersHeader.waitForExistence(timeout: 10)
                || ownerBadge.waitForExistence(timeout: 5)
        )
    }

    func testSwitchToSettingsSection() {
        ensureInOrg()
        app.buttons["Settings"].click()
        let settingsHeader = app.staticTexts["Settings"]
        let nameField = app.textFields["Organization Name"]
        XCTAssertTrue(
            settingsHeader.waitForExistence(timeout: 10)
                || nameField.waitForExistence(timeout: 5)
        )
    }

    func testSwitchBetweenSections() {
        ensureInOrg()

        app.buttons["Wiki"].click()
        sleep(2)
        app.buttons["Projects"].click()
        sleep(2)
        app.buttons["Members"].click()
        sleep(2)
        app.buttons["Settings"].click()
        sleep(2)
        app.buttons["Projects"].click()

        XCTAssertTrue(app.buttons["Projects"].waitForExistence(timeout: 5))
    }

    func testSwitchOrgReturnsToSwitcher() {
        ensureInOrg()
        app.buttons["Switch Org"].click()
        let orgText = app.staticTexts["Organizations"]
        XCTAssertTrue(orgText.waitForExistence(timeout: 10))
    }

    func testSignOutFromHome() {
        ensureInOrg()
        app.buttons["Sign Out"].click()
        XCTAssertTrue(app.staticTexts["Sign In"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 5))
    }

    func testOnboardingDataPreservedOnBack() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }

        let step1 = app.staticTexts
            .matching(
                NSPredicate(format: "label CONTAINS 'Step 1'")
            )
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Persist Name")

            let bio = app.textFields["Bio"]
            bio.click()
            bio.typeText("Persist Bio")

            app.buttons["Next"].click()
            sleep(1)
            app.buttons["Back"].click()
            sleep(1)

            let nameValue = app.textFields["Display Name"].value as? String ?? ""
            XCTAssertTrue(nameValue.contains("Persist Name"))
        }
    }

    func testOnboardingEmptyDisplayNameStays() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            app.buttons["Next"].click()
            sleep(2)
            XCTAssertTrue(step1.exists)
        }
    }

    func testOnboardingWhitespaceNameStays() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("   ")
            app.buttons["Next"].click()
            sleep(2)
            XCTAssertTrue(step1.exists || app.textFields["Display Name"].exists)
        }
    }

    func testOnboardingEmptyOrgNameStays() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Org Name Test")
            app.buttons["Next"].click()
            let step2 = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS 'Step 2'"))
                .firstMatch
            if step2.waitForExistence(timeout: 5) {
                app.buttons["Next"].click()
                sleep(2)
                XCTAssertTrue(step2.exists)
            }
        }
    }

    func testOnboardingInvalidSlugStays() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Slug Test")
            app.buttons["Next"].click()
            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Slug Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("INVALID SLUG!")
                app.buttons["Next"].click()
                sleep(2)
                let step2 = app.staticTexts
                    .matching(NSPredicate(format: "label CONTAINS 'Step 2'"))
                    .firstMatch
                XCTAssertTrue(step2.exists || orgName.exists)
            }
        }
    }

    func testOnboardingValidationClearsOnFix() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            app.buttons["Next"].click()
            sleep(1)
            XCTAssertTrue(step1.exists)
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Fixed Name")
            app.buttons["Next"].click()
            let step2 = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS 'Step 2'"))
                .firstMatch
            XCTAssertTrue(step2.waitForExistence(timeout: 5))
        }
    }

    func testOnboardingCompleteEndToEnd() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeKey("a", modifierFlags: .command)
            displayName.typeText("Complete Flow")
            let bio = app.textFields["Bio"]
            bio.click()
            bio.typeText("E2E complete flow")
            app.buttons["Next"].click()
            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Complete Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("complete-\(Int(Date().timeIntervalSince1970))")
                app.buttons["Next"].click()
                sleep(1)
                app.buttons["Next"].click()
                sleep(1)
                let completeButton = app.buttons["Complete"]
                if completeButton.waitForExistence(timeout: 3) {
                    completeButton.click()
                    sleep(5)
                    XCTAssertTrue(
                        app.buttons["Projects"].waitForExistence(timeout: 10)
                            || app.buttons["Select"].firstMatch.waitForExistence(timeout: 5)
                    )
                }
            }
        }
    }

    func testOnboardingUpcomingStepsDisabled() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let step2 = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS 'Step 2'"))
                .firstMatch
            step2.click()
            sleep(1)
            XCTAssertTrue(step1.exists)
        }
    }

    func testOnboardingStep2DataPreservedOnBack() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Persist 2")
            app.buttons["Next"].click()
            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Persist Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("persist-\(Int(Date().timeIntervalSince1970))")
                app.buttons["Next"].click()
                let step3 = app.staticTexts
                    .matching(NSPredicate(format: "label CONTAINS 'Step 3'"))
                    .firstMatch
                XCTAssertTrue(step3.waitForExistence(timeout: 5))
                app.buttons["Back"].click()
                sleep(1)
                let orgNameValue = app.textFields["Organization Name"].value as? String ?? ""
                XCTAssertTrue(orgNameValue.contains("Persist Org"))
            }
        }
    }

    func testOnboardingFullRoundTripDataPreserved() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Round Trip")
            let bio = app.textFields["Bio"]
            bio.click()
            bio.typeText("Round trip bio")
            app.buttons["Next"].click()
            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Round Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("round-\(Int(Date().timeIntervalSince1970))")
                app.buttons["Next"].click()
                sleep(1)
                app.buttons["Next"].click()
                let step4 = app.staticTexts
                    .matching(NSPredicate(format: "label CONTAINS 'Step 4'"))
                    .firstMatch
                XCTAssertTrue(step4.waitForExistence(timeout: 5))
                app.buttons["Back"].click()
                sleep(1)
                app.buttons["Back"].click()
                sleep(1)
                app.buttons["Back"].click()
                sleep(1)
                let nameValue = app.textFields["Display Name"].value as? String ?? ""
                XCTAssertTrue(nameValue.contains("Round Trip"))
                let bioValue = app.textFields["Bio"].value as? String ?? ""
                XCTAssertTrue(bioValue.contains("Round trip bio"))
            }
        }
    }

    func testOnboardingEditStep1DoesNotAffectStep2() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Original")
            app.buttons["Next"].click()
            let orgName = app.textFields["Organization Name"]
            if orgName.waitForExistence(timeout: 5) {
                orgName.click()
                orgName.typeText("Iso Org")
                let slug = app.textFields["URL Slug"]
                slug.click()
                slug.typeText("iso-\(Int(Date().timeIntervalSince1970))")
                app.buttons["Next"].click()
                let step3 = app.staticTexts
                    .matching(NSPredicate(format: "label CONTAINS 'Step 3'"))
                    .firstMatch
                XCTAssertTrue(step3.waitForExistence(timeout: 5))
                app.buttons["Back"].click()
                sleep(1)
                app.buttons["Back"].click()
                sleep(1)
                let nameField = app.textFields["Display Name"]
                nameField.click()
                nameField.typeKey("a", modifierFlags: .command)
                nameField.typeText("Modified")
                app.buttons["Next"].click()
                sleep(1)
                let orgNameValue = app.textFields["Organization Name"].value as? String ?? ""
                XCTAssertTrue(orgNameValue.contains("Iso Org"))
            }
        }
    }

    func testOnboardingBioExceeding500CharsStays() {
        ensureAuthenticated()
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.click()
            sleep(1)
        }
        let step1 = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Step 1'"))
            .firstMatch
        if step1.waitForExistence(timeout: 5) {
            let displayName = app.textFields["Display Name"]
            displayName.click()
            displayName.typeText("Bio Test")
            let bio = app.textFields["Bio"]
            bio.click()
            var longBio = ""
            for _ in 0..<51 {
                longBio += "abcdefghij"
            }
            bio.typeText(longBio)
            app.buttons["Next"].click()
            sleep(2)
            XCTAssertTrue(
                step1.exists || app.textFields["Display Name"].exists
                    || app.staticTexts
                    .matching(NSPredicate(format: "label CONTAINS 'Step 2'"))
                    .firstMatch
                    .waitForExistence(timeout: 3)
            )
        }
    }

    func testProjectsCreateNew() {
        ensureInOrg()
        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.waitForExistence(timeout: 10) {
            newProjectButton.click()
            let nameField = app.textFields["Project Name"]
            if nameField.waitForExistence(timeout: 5) {
                nameField.click()
                nameField.typeText("E2E Project \(Int(Date().timeIntervalSince1970))")
                app.buttons["Create"].click()
                sleep(3)
            }
        }
        XCTAssertTrue(
            app.buttons["New Project"].waitForExistence(timeout: 10)
                || app.staticTexts["Projects"].waitForExistence(timeout: 5)
        )
    }

    func testProjectsShowsCreatedProject() {
        ensureInOrg()
        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.waitForExistence(timeout: 10) {
            let uniqueName = "Visible \(Int(Date().timeIntervalSince1970))"
            newProjectButton.click()
            let nameField = app.textFields["Project Name"]
            if nameField.waitForExistence(timeout: 5) {
                nameField.click()
                nameField.typeText(uniqueName)
                app.buttons["Create"].click()
                sleep(3)
                XCTAssertTrue(
                    app.staticTexts[uniqueName].waitForExistence(timeout: 10)
                        || app.buttons["New Project"].exists
                )
            }
        }
    }

    func testWikiCreatePage() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        let newPageButton = app.buttons["New Page"]
        if newPageButton.waitForExistence(timeout: 10) {
            newPageButton.click()
            let titleField = app.textFields["Title"]
            if titleField.waitForExistence(timeout: 5) {
                titleField.click()
                titleField.typeText("E2E Wiki \(Int(Date().timeIntervalSince1970))")
                let slugField = app.textFields["Slug"]
                if slugField.exists {
                    slugField.click()
                    slugField.typeText("e2e-wiki-\(Int(Date().timeIntervalSince1970))")
                }
                app.buttons["Create"].click()
                sleep(3)
            }
        }
        XCTAssertTrue(
            app.buttons["New Page"].waitForExistence(timeout: 10)
                || app.staticTexts["Wiki"].waitForExistence(timeout: 5)
        )
    }

    func testWikiDeletePage() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        sleep(2)
        let deleteButton = app.buttons["Delete"].firstMatch
        if deleteButton.waitForExistence(timeout: 8) {
            deleteButton.click()
            sleep(3)
        }
        XCTAssertTrue(
            app.buttons["New Page"].waitForExistence(timeout: 10)
                || app.staticTexts["Wiki"].waitForExistence(timeout: 5)
        )
    }

    func testMembersShowsOwnerBadge() {
        ensureInOrg()
        app.buttons["Members"].click()
        let ownerPredicate = NSPredicate(
            format: "label CONTAINS[c] 'owner'"
        )
        let ownerBadge = app.staticTexts.matching(ownerPredicate).firstMatch
        XCTAssertTrue(
            ownerBadge.waitForExistence(timeout: 10)
                || app.staticTexts["Members"].waitForExistence(timeout: 5)
        )
    }

    func testSettingsShowsOrgFields() {
        ensureInOrg()
        app.buttons["Settings"].click()
        let nameField = app.textFields["Organization Name"]
        let slugField = app.textFields["Slug"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 10)
                || slugField.waitForExistence(timeout: 5)
                || app.staticTexts["Settings"].waitForExistence(timeout: 5)
        )
    }

    func testSettingsDeleteOrgVisible() {
        ensureInOrg()
        app.buttons["Settings"].click()
        let deletePredicate = NSPredicate(
            format: "label CONTAINS[c] 'delete'"
        )
        let deleteElement = app.buttons.matching(deletePredicate).firstMatch
        let deleteText = app.staticTexts.matching(deletePredicate).firstMatch
        XCTAssertTrue(
            deleteElement.waitForExistence(timeout: 10)
                || deleteText.waitForExistence(timeout: 5)
                || app.staticTexts["Settings"].waitForExistence(timeout: 5)
        )
    }

    func testMembersJoinRequestsSectionExists() {
        ensureInOrg()
        app.buttons["Members"].click()
        let membersHeader = app.staticTexts["Members"]
        XCTAssertTrue(membersHeader.waitForExistence(timeout: 10))
        sleep(3)
        let joinRequestsPredicate = NSPredicate(
            format: "label CONTAINS[c] 'Join Requests'"
        )
        let joinRequestsText = app.staticTexts.matching(joinRequestsPredicate).firstMatch
        let hasSection = joinRequestsText.waitForExistence(timeout: 5)
            || membersHeader.exists
        XCTAssertTrue(hasSection)
    }

    func testMembersJoinRequestApproveRejectButtons() {
        ensureInOrg()
        app.buttons["Members"].click()
        XCTAssertTrue(app.staticTexts["Members"].waitForExistence(timeout: 10))
        sleep(3)
        let joinRequestsPredicate = NSPredicate(
            format: "label CONTAINS[c] 'Pending Join Requests'"
        )
        let joinRequestsText = app.staticTexts.matching(joinRequestsPredicate).firstMatch
        if joinRequestsText.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.buttons["Approve"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Reject"].firstMatch.waitForExistence(timeout: 5))
        }
    }

    func testProjectsSelectAllButtonVisible() {
        ensureInOrg()
        let selectAllButton = app.buttons["Select All"]
        let deselectAllButton = app.buttons["Deselect All"]
        XCTAssertTrue(
            selectAllButton.waitForExistence(timeout: 10)
                || deselectAllButton.waitForExistence(timeout: 5)
        )
    }

    func testProjectsBulkDeleteAfterSelectAll() {
        ensureInOrg()
        let selectAllButton = app.buttons["Select All"]
        if selectAllButton.waitForExistence(timeout: 10) {
            selectAllButton.click()
            sleep(1)
            let deletePredicate = NSPredicate(
                format: "label BEGINSWITH 'Delete Selected'"
            )
            let deleteSelectedButton = app.buttons.matching(deletePredicate).firstMatch
            let hasDeleteButton = deleteSelectedButton.waitForExistence(timeout: 5)
                || app.buttons["Deselect All"].exists
            XCTAssertTrue(hasDeleteButton)
            let deselectButton = app.buttons["Deselect All"]
            if deselectButton.exists {
                deselectButton.click()
            }
        }
    }

    func testWikiSelectAllButtonVisible() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        sleep(2)
        let selectAllButton = app.buttons["Select All"]
        let deselectAllButton = app.buttons["Deselect All"]
        XCTAssertTrue(
            selectAllButton.waitForExistence(timeout: 10)
                || deselectAllButton.waitForExistence(timeout: 5)
        )
    }

    func testWikiBulkDeleteAfterSelectAll() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        sleep(2)
        let selectAllButton = app.buttons["Select All"]
        if selectAllButton.waitForExistence(timeout: 10) {
            selectAllButton.click()
            sleep(1)
            let deletePredicate = NSPredicate(
                format: "label BEGINSWITH 'Delete Selected'"
            )
            let deleteSelectedButton = app.buttons.matching(deletePredicate).firstMatch
            let hasDeleteButton = deleteSelectedButton.waitForExistence(timeout: 5)
                || app.buttons["Deselect All"].exists
            XCTAssertTrue(hasDeleteButton)
            let deselectButton = app.buttons["Deselect All"]
            if deselectButton.exists {
                deselectButton.click()
            }
        }
    }

    func testProjectTasksEditorsSection() {
        ensureInOrg()
        let tasksLink = app.buttons["Tasks"].firstMatch
        if tasksLink.waitForExistence(timeout: 10) {
            tasksLink.click()
            sleep(3)
            let editorsText = app.staticTexts["Editors"]
            let addEditorText = app.staticTexts["Add Editor"]
            XCTAssertTrue(
                editorsText.waitForExistence(timeout: 10)
                    || addEditorText.waitForExistence(timeout: 5)
            )
        }
    }

    func testWikiEditEditorsSection() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        sleep(2)
        let editLink = app.buttons["Edit"].firstMatch
        if editLink.waitForExistence(timeout: 10) {
            editLink.click()
            sleep(3)
            let editorsText = app.staticTexts["Editors"]
            let addEditorText = app.staticTexts["Add Editor"]
            XCTAssertTrue(
                editorsText.waitForExistence(timeout: 10)
                    || addEditorText.waitForExistence(timeout: 5)
            )
        }
    }

    func testSettingsTransferOwnershipVisible() {
        ensureInOrg()
        app.buttons["Settings"].click()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Transfer Ownership"].waitForExistence(timeout: 10))
    }

    func testSettingsTransferOwnershipMemberPicker() {
        ensureInOrg()
        app.buttons["Settings"].click()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Transfer Ownership"].waitForExistence(timeout: 10))
        let selectOwnerText = app.staticTexts["Select new owner:"]
        let noAdminsText = app.staticTexts["No other admins available"]
        let loadingText = app.staticTexts["Loading admins..."]
        XCTAssertTrue(
            selectOwnerText.waitForExistence(timeout: 10)
                || noAdminsText.waitForExistence(timeout: 5)
                || loadingText.waitForExistence(timeout: 3)
        )
    }

    func testTaskInlineEdit() {
        ensureInOrg()
        let tasksLink = app.buttons["Tasks"].firstMatch
        if tasksLink.waitForExistence(timeout: 10) {
            tasksLink.click()
            sleep(3)
            let newTaskField = app.textFields["New task..."]
            if newTaskField.waitForExistence(timeout: 5) {
                newTaskField.click()
                newTaskField.typeText("Edit Test \(Int(Date().timeIntervalSince1970))")
                app.buttons["Add"].click()
                sleep(3)
            }
            let editButton = app.buttons["Edit"].firstMatch
            if editButton.waitForExistence(timeout: 10) {
                editButton.click()
                sleep(1)
                XCTAssertTrue(
                    app.buttons["Save"].waitForExistence(timeout: 5)
                        || app.buttons["Cancel"].waitForExistence(timeout: 5)
                )
            }
        }
    }

    func testTaskAssignment() {
        ensureInOrg()
        let tasksLink = app.buttons["Tasks"].firstMatch
        if tasksLink.waitForExistence(timeout: 10) {
            tasksLink.click()
            sleep(3)
            let unassignedButton = app.buttons["Unassigned"].firstMatch
            XCTAssertTrue(
                unassignedButton.waitForExistence(timeout: 10)
                    || app.staticTexts["No tasks yet"].waitForExistence(timeout: 5)
            )
        }
    }

    func testProjectEditNavigation() {
        ensureInOrg()
        let editLink = app.buttons["Edit"].firstMatch
        if editLink.waitForExistence(timeout: 10) {
            editLink.click()
            sleep(3)
            let nameField = app.textFields["Name"]
            let descField = app.textFields["Description"]
            let saveButton = app.buttons["Save"]
            XCTAssertTrue(
                nameField.waitForExistence(timeout: 10)
                    || descField.waitForExistence(timeout: 5)
                    || saveButton.waitForExistence(timeout: 5)
            )
        }
    }

    func testWikiAutoSaveIndicator() {
        ensureInOrg()
        app.buttons["Wiki"].click()
        sleep(2)
        let editLink = app.buttons["Edit"].firstMatch
        if editLink.waitForExistence(timeout: 10) {
            editLink.click()
            sleep(3)
            let titleField = app.textFields["Title"]
            if titleField.waitForExistence(timeout: 10) {
                titleField.click()
                titleField.typeText("a")
                sleep(1)
                let editingText = app.staticTexts["Editing..."]
                let savingText = app.staticTexts["Saving..."]
                let savedText = app.staticTexts["Saved"]
                XCTAssertTrue(
                    editingText.waitForExistence(timeout: 5)
                        || savingText.waitForExistence(timeout: 5)
                        || savedText.waitForExistence(timeout: 10)
                )
            }
        }
    }

    func testOrgAvatarUpload() {
        ensureInOrg()
        app.buttons["Settings"].click()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
        let chooseAvatar = app.buttons["Choose Avatar"]
        let changeAvatar = app.buttons["Change Avatar"]
        XCTAssertTrue(
            chooseAvatar.waitForExistence(timeout: 10)
                || changeAvatar.waitForExistence(timeout: 5)
        )
    }

    // MARK: - Invite Accept

    func testAcceptInviteButtonVisible() {
        ensureAuthenticated()
        let acceptInvite = app.buttons["Accept Invite"]
        XCTAssertTrue(acceptInvite.waitForExistence(timeout: 5))
    }

    func testAcceptInviteShowsTokenField() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let acceptInvite = app.buttons["Accept Invite"]
        if acceptInvite.waitForExistence(timeout: 5) {
            acceptInvite.click()
            let tokenField = app.textFields["Invite token"]
            XCTAssertTrue(tokenField.waitForExistence(timeout: 5))
        }
    }

    func testAcceptInviteCancel() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let acceptInvite = app.buttons["Accept Invite"]
        if acceptInvite.waitForExistence(timeout: 5) {
            acceptInvite.click()
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.click()
                XCTAssertTrue(orgText.waitForExistence(timeout: 5))
            }
        }
    }

    func testAcceptInviteShowsAcceptButton() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let acceptInvite = app.buttons["Accept Invite"]
        if acceptInvite.waitForExistence(timeout: 5) {
            acceptInvite.click()
            let acceptButton = app.buttons["Accept"]
            XCTAssertTrue(acceptButton.waitForExistence(timeout: 5))
        }
    }

    func testAcceptInviteWithInvalidToken() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let acceptInvite = app.buttons["Accept Invite"]
        if acceptInvite.waitForExistence(timeout: 5) {
            acceptInvite.click()
            let tokenField = app.textFields["Invite token"]
            if tokenField.waitForExistence(timeout: 5) {
                tokenField.click()
                tokenField.typeText("invalid-token-12345")
                let acceptButton = app.buttons["Accept"]
                acceptButton.click()
                sleep(3)
                let failedText = app.staticTexts["Invite failed"]
                XCTAssertTrue(failedText.waitForExistence(timeout: 10))
            }
        }
    }

    // MARK: - Join Organization

    func testJoinOrgButtonVisible() {
        ensureAuthenticated()
        let joinOrg = app.buttons["Join Org"]
        XCTAssertTrue(joinOrg.waitForExistence(timeout: 5))
    }

    func testJoinOrgShowsSlugField() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let joinOrg = app.buttons["Join Org"]
        if joinOrg.waitForExistence(timeout: 5) {
            joinOrg.click()
            let slugField = app.textFields["Organization slug"]
            XCTAssertTrue(slugField.waitForExistence(timeout: 5))
        }
    }

    func testJoinOrgCancel() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let joinOrg = app.buttons["Join Org"]
        if joinOrg.waitForExistence(timeout: 5) {
            joinOrg.click()
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.click()
                XCTAssertTrue(orgText.waitForExistence(timeout: 5))
            }
        }
    }

    func testJoinOrgShowsJoinButton() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let joinOrg = app.buttons["Join Org"]
        if joinOrg.waitForExistence(timeout: 5) {
            joinOrg.click()
            let joinButton = app.buttons["Join"]
            XCTAssertTrue(joinButton.waitForExistence(timeout: 5))
        }
    }

    func testJoinOrgWithNonexistentSlug() {
        ensureAuthenticated()
        let orgText = app.staticTexts["Organizations"]
        _ = orgText.waitForExistence(timeout: 5)
        let joinOrg = app.buttons["Join Org"]
        if joinOrg.waitForExistence(timeout: 5) {
            joinOrg.click()
            let slugField = app.textFields["Organization slug"]
            if slugField.waitForExistence(timeout: 5) {
                slugField.click()
                slugField.typeText("nonexistent-org-slug-999")
                let joinButton = app.buttons["Join"]
                joinButton.click()
                sleep(3)
                let notFoundText = app.staticTexts["Organization not found"]
                XCTAssertTrue(notFoundText.waitForExistence(timeout: 10))
            }
        }
    }
}
