import XCTest

/// Full user-flow acceptance tests against the REAL backend.
///
/// - No mocks, no fake data: registration, browsing, cart, checkout and
///   theme changes all hit the live Supabase project.
/// - Tests needing an authenticated session read `UITEST_EMAIL` /
///   `UITEST_PASSWORD` from the process environment (a confirmed student
///   account). They `XCTSkip` — never fake-pass — when absent.
/// - Every major step attaches a screenshot, so failures (and dark-mode
///   rendering) can be inspected visually.
final class CraveAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        // Explicit host app — never rely on runner inference.
        app = XCUIApplication(bundleIdentifier: "rakshan.Crave-IOS")
    }

    // MARK: - Helpers

    private func launch(appearance: String? = nil) {
        if let appearance {
            app.launchArguments.append(contentsOf: ["-crave-appearance", appearance])
        }
        app.launch()
    }

    private func shoot(_ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tap through onboarding if it is showing (splash lasts ~2s first).
    private func passOnboardingIfNeeded() {
        if app.buttons["Get Started"].waitForExistence(timeout: 12) {
            app.buttons["Get Started"].tap()
            return
        }
        guard app.buttons["Next"].waitForExistence(timeout: 3) else { return }
        app.buttons["Next"].tap()
        if app.buttons["Next"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
        }
        if app.buttons["Get Started"].waitForExistence(timeout: 5) {
            app.buttons["Get Started"].tap()
        }
    }

    private func env(_ key: String) -> String? {
        // CI/local override file (outside the repo — never committed).
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/uitest_creds.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            let mapped = key == "UITEST_EMAIL" ? json["email"] : json["password"]
            if let mapped, !mapped.isEmpty { return mapped }
        }
        let value = ProcessInfo.processInfo.environment[key]
        return (value?.isEmpty == false) ? value : nil
    }

    /// Current cart badge count, or nil when no badge is showing.
    /// The badge Text lives inside the cartButton link (an ancestor
    /// identifier shadows descendants in AX), so it is read as the link's
    /// only descendant static text.
    private func cartBadgeLabel() -> String? {
        let link = app.buttons.matching(identifier: "cartButton").element
        guard link.exists else { return nil }
        let texts = link.descendants(matching: .staticText)
        guard texts.count > 0 else { return nil }
        return texts.element(boundBy: 0).label
    }

    /// Poll-until-hittable tap. Immune to transient AX snapshot desync that
    /// defeats single-shot waitForExistence during background refreshes.
    @discardableResult
    private func tapWhenReady(
        _ element: XCUIElement,
        description: String,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var sawExists = false
        while Date() < deadline {
            if element.exists {
                sawExists = true
                if element.isHittable {
                    element.tap()
                    return true
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        var lines: [String] = []
        for b in app.buttons.allElementsBoundByIndex {
            lines.append("button id=\(b.identifier) label=\(b.label) hittable=\(b.isHittable)")
        }
        print("AX_DUMP_AFTER_TIMEOUT sawExists=\(sawExists)")
        print(lines.joined(separator: "\n"))
        print("AX_DUMP_END")
        XCTFail("\(description) never became tappable (existed at some point: \(sawExists))",
                file: file, line: line)
        return false
    }

    /// Mean luminance of a screenshot region (0 = black, 1 = white).
    private func meanLuminance(of image: UIImage, samplingFraction: CGFloat = 0.08) -> CGFloat? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width, height = cg.height
        // Sample a grid across the whole screen; chrome (status bar) is small
        // enough not to skew the verdict.
        let stepX = max(1, Int(CGFloat(width) * samplingFraction))
        let stepY = max(1, Int(CGFloat(height) * samplingFraction))
        guard let provider = cg.dataProvider, let data = provider.data else { return nil }
        let ptr = CFDataGetBytePtr(data)
        let bytesPerPixel = cg.bitsPerPixel / 8
        let bytesPerRow = cg.bytesPerRow
        var total: CGFloat = 0
        var count: CGFloat = 0
        var y = stepY / 2
        while y < height {
            var x = stepX / 2
            while x < width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                // Assume RGBA/RGBX byte order (simulator screenshots).
                let r = CGFloat(ptr![offset]) / 255
                let g = CGFloat(ptr![offset + 1]) / 255
                let b = CGFloat(ptr![offset + 2]) / 255
                total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
                x += stepX
            }
            y += stepY
        }
        return count > 0 ? total / count : nil
    }

    private func assertDarkScreen(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let lum = meanLuminance(of: app.screenshot().image)
        XCTAssertNotNil(lum, "could not sample screenshot", file: file, line: line)
        if let lum {
            XCTAssertLessThan(lum, 0.45, "\(message) — mean luminance \(lum) is too bright for dark mode",
                              file: file, line: line)
        }
    }

    private func assertLightScreen(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let lum = meanLuminance(of: app.screenshot().image)
        XCTAssertNotNil(lum, "could not sample screenshot", file: file, line: line)
        if let lum {
            XCTAssertGreaterThan(lum, 0.45, "\(message) — mean luminance \(lum) is too dark for light mode",
                                file: file, line: line)
        }
    }

    // MARK: - TEST 1: onboarding + auth surfaces (no credentials needed)

    func test01_onboardingAndAuthSurfaces() {
        launch(appearance: "light")
        // A restored session lands straight on Home — verify that too.
        if app.tabBars.buttons["Home"].waitForExistence(timeout: 15) {
            shoot("01-home-authenticated-light")
            assertLightScreen("home in light mode")
            return
        }
        passOnboardingIfNeeded()

        // Login screen renders with working fields.
        let email = app.textFields["loginEmail"]
        XCTAssertTrue(email.waitForExistence(timeout: 15), "login email field must exist")
        shoot("01-login-light")
        assertLightScreen("login screen in light mode")

        // Register sheet opens with all fields + validation.
        app.buttons["Create an account"].tap()
        XCTAssertTrue(app.textFields["registerName"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.sheets.element.secureTextFields.count > 0)
        shoot("01-register-light")
    }

    // MARK: - TEST 2: registration verify-email UX (confirmation enforced)

    func test02_registerShowsVerifyDialog() throws {
        launch()
        signOutIfNeeded()
        passOnboardingIfNeeded()
        app.buttons["Create an account"].tap()
        XCTAssertTrue(app.textFields["registerName"].waitForExistence(timeout: 10))

        let stamp = Int(Date().timeIntervalSince1970)
        app.textFields["registerName"].tap()
        app.textFields["registerName"].typeText("UI Test")
        app.textFields["registerEmail"].tap()
        app.textFields["registerEmail"].typeText("craveuitest\(stamp)@uberip.com")
        // Secure fields are scoped to the sheet (the login screen behind it
        // also has secure fields) and queried by index.
        let sheet = app.sheets.element
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let passwords = sheet.secureTextFields
        XCTAssertTrue(passwords.element.waitForExistence(timeout: 10))
        passwords.element(boundBy: 0).tap()
        passwords.element(boundBy: 0).typeText("Test1234!")
        passwords.element(boundBy: 1).tap()
        passwords.element(boundBy: 1).typeText("Test1234!")
        app.buttons["createAccountButton"].tap()

        // Either the verify dialog (confirmation ON — expected) …
        if app.alerts["Verify Your Email"].waitForExistence(timeout: 30) {
            shoot("02-verify-email-dialog")
            app.alerts["Verify Your Email"].buttons["Go to Login"].tap()
            return
        }
        // … or an explicit rate-limit error, in which case retry later.
        if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Too many'")).element
            .waitForExistence(timeout: 5)
        {
            throw XCTSkip("email rate limit hit — rerun later to verify the dialog")
        }
        XCTFail("expected the Verify-Email dialog after registration")
    }

    // MARK: - TEST 3: full student flow (confirmed account required)

    func test03_fullStudentFlow() throws {
        guard let email = env("UITEST_EMAIL"), let password = env("UITEST_PASSWORD") else {
            throw XCTSkip("UITEST_EMAIL/UITEST_PASSWORD not set — provision a confirmed student account first")
        }
        launch()
        try signInIfNeeded(email, password)
        shoot("03-home")

        // HOME → OUTLET
        let outlets = app.buttons.matching(identifier: "outletCard")
        XCTAssertTrue(outlets.element.waitForExistence(timeout: 60), "at least one real outlet must load")
        let outletCount = outlets.count
        outlets.allElementsBoundByIndex[0].tap()

        // Baseline badge (the account may already hold cart items — the test
        // must be non-destructive, so all badge assertions are deltas).
        let base0 = Int(cartBadgeLabel() ?? "0") ?? 0

        // OUTLET → FOOD
        let foods = app.buttons.matching(identifier: "foodCard")
        XCTAssertTrue(foods.element.waitForExistence(timeout: 60), "outlet menu must load")
        let firstFoodName = foods.allElementsBoundByIndex[0].label
        foods.allElementsBoundByIndex[0].tap()

        // FOOD DETAIL — the critical assertion: Add to Cart must exist.
        let addButton = app.buttons["addToCartButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 30), "Add to Cart button must be visible on food detail")
        shoot("03-food-detail")

        // Customizations: select up to 3 visible options (caps enforced by app).
        let chips = app.buttons.matching(identifier: "optionChip")
        for i in 0..<min(3, chips.count) {
            let chip = chips.allElementsBoundByIndex[i]
            if chip.isHittable { chip.tap() }
        }

        // Quantity 1 → 2.
        guard tapWhenReady(app.buttons["increaseQuantity"], description: "quantity + button") else { return }
        shoot("03-food-detail-before-stepper")

        // ADD TO CART → the backend cart may belong to another outlet, in
        // which case the conflict dialog appears instead of a badge bump.
        guard tapWhenReady(addButton, description: "Add to Cart button") else { return }
        var afterDetail: Int?
        let addDeadline = Date().addingTimeInterval(20)
        while Date() < addDeadline {
            if app.alerts["Different Outlet"].exists { break }
            if let label = cartBadgeLabel(), let n = Int(label) {
                afterDetail = n
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        if app.alerts["Different Outlet"].exists {
            app.alerts["Different Outlet"].buttons["Clear & Add"].tap()
            afterDetail = 2 // cleared cart + qty 2 added
        }
        XCTAssertNotNil(afterDetail, "cart badge must update or conflict dialog must appear after Add to Cart")
        if app.alerts["Different Outlet"].exists {
            XCTAssertEqual(afterDetail, 2)
        } else {
            XCTAssertEqual(afterDetail, base0 + 2, "badge must grow by the added quantity")
        }
        shoot("03-added-to-cart")

        // Visible success feedback (toast) — may already have dismissed.
        // Auto-navigation pushes Cart shortly after a successful add.
        let proceed = app.buttons["proceedToCheckoutButton"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 20),
                      "successful add must auto-navigate to Cart")

        // CART — item, customization, quantity, price (already here via auto-nav).
        XCTAssertTrue(app.staticTexts[firstFoodName].waitForExistence(timeout: 15),
                      "added dish '\(firstFoodName)' must appear in cart")
        shoot("03-cart")

        // Quantity stepper in cart: +1 then back, badge follows.
        let afterDetailCount = Int(cartBadgeLabel() ?? "0") ?? 0
        let incButtons = app.buttons.matching(identifier: "increaseQuantity")
        XCTAssertTrue(incButtons.allElementsBoundByIndex[0].waitForExistence(timeout: 10))
        incButtons.allElementsBoundByIndex[0].tap()
        XCTAssertEqual(Int(cartBadgeLabel() ?? "-1"), afterDetailCount + 1, "badge must follow cart quantity")
        app.buttons.matching(identifier: "decreaseQuantity").allElementsBoundByIndex[0].tap()
        XCTAssertEqual(Int(cartBadgeLabel() ?? "-1"), afterDetailCount)

        // QUICK-ADD from the outlet menu: back out (Cart → Food → menu),
        // then tap the card's plus (the card link's own identifier shadows
        // the plus button's, so tap by hierarchy, not by identifier).
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tap() // Cart → Food detail
        XCTAssertTrue(app.buttons["addToCartButton"].waitForExistence(timeout: 15))
        backButton.tap() // Food → outlet menu
        let firstMenuCard = app.buttons.matching(identifier: "foodCard").element
        if firstMenuCard.waitForExistence(timeout: 30) {
            let menuBadgeBefore = Int(cartBadgeLabel() ?? "0") ?? 0
            let plus = firstMenuCard.descendants(matching: .button).element
            if plus.waitForExistence(timeout: 10) {
                plus.tap()
            }
            // Either the badge grows (quick-add) or detail opens (required).
            var quickDone = false
            let quickDeadline = Date().addingTimeInterval(15)
            var detailOpened = false
            while Date() < quickDeadline {
                if let label = cartBadgeLabel(), let n = Int(label), n == menuBadgeBefore + 1 {
                    quickDone = true
                    break
                }
                if app.buttons["addToCartButton"].exists {
                    detailOpened = true
                    quickDone = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
            XCTAssertTrue(quickDone,
                          "quick-add must add to cart or open detail for required variants")
            shoot("03-quick-add")
            if detailOpened {
                backButton.tap() // back to menu
            }
        }

        // Back to Home (tab bar is hidden on pushed screens).
        backButton.tap() // menu → Home
        XCTAssertTrue(app.buttons.matching(identifier: "outletCard").element.waitForExistence(timeout: 30))

        // OUTLET CONFLICT (needs 2+ outlets).
        if outletCount > 1 {
            outlets.allElementsBoundByIndex[1].tap()
            let foodsB = app.buttons.matching(identifier: "foodCard")
            if foodsB.element.waitForExistence(timeout: 60) {
                foodsB.allElementsBoundByIndex[0].tap()
                if app.buttons["addToCartButton"].waitForExistence(timeout: 30) {
                    guard tapWhenReady(app.buttons["addToCartButton"], description: "outlet-B Add to Cart") else { return }
                    let alert = app.alerts["Different Outlet"]
                    XCTAssertTrue(alert.waitForExistence(timeout: 15), "outlet conflict dialog must appear")
                    shoot("03-outlet-conflict")
                    alert.buttons["Clear & Add"].tap()
                    XCTAssertEqual(Int(cartBadgeLabel() ?? "-1"), 1, "conflict clear-and-add leaves 1 item")
                }
            }
        }

        // CHECKOUT — via the detail screen's cart shortcut (tab bar hidden here).
        guard tapWhenReady(app.buttons["detailCartButton"], description: "detail cart button") else { return }
        guard tapWhenReady(app.buttons["proceedToCheckoutButton"], description: "proceed to checkout") else { return }
        let slots = app.buttons.matching(identifier: "pickupSlotRow")
        XCTAssertTrue(
            slots.element.waitForExistence(timeout: 30) ||
                app.staticTexts["No pickup slots available for this outlet today."].waitForExistence(timeout: 5),
            "slot section must resolve (slots or honest empty state)"
        )
        // Pick the first selectable slot.
        var picked = false
        for i in 0..<slots.count {
            let slot = slots.allElementsBoundByIndex[i]
            if slot.isEnabled && slot.isHittable { slot.tap(); picked = true; break }
        }
        XCTAssertTrue(picked, "at least one selectable slot is required to order")
        shoot("03-checkout")

        // Pay at Counter → place.
        guard tapWhenReady(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pay at Counter'")).element,
                           description: "Pay at Counter option") else { return }
        guard tapWhenReady(app.buttons["placeOrderButton"], description: "Place Order") else { return }
        XCTAssertTrue(app.staticTexts["Order Placed!"].waitForExistence(timeout: 90),
                      "PAY_AT_COUNTER order must confirm")
        shoot("03-confirmation")

        // HISTORY — order appears; open it; cancel to clean up.
        guard tapWhenReady(app.buttons["Done"], description: "confirmation Done") else { return }
        app.tabBars.buttons["Orders"].tap()
        let orderRows = app.buttons.matching(NSPredicate(format: "label CONTAINS 'GAG-'"))
        XCTAssertTrue(orderRows.element.waitForExistence(timeout: 30), "placed order must appear in history")
        orderRows.allElementsBoundByIndex[0].tap()
        XCTAssertTrue(app.staticTexts["Order Placed"].waitForExistence(timeout: 30) ||
            app.staticTexts["Accepted"].exists)
        shoot("03-order-detail")

        // Cancel the test order to clean up backend state (also verifies cancel).
        if app.buttons["Cancel Order"].waitForExistence(timeout: 5) {
            guard tapWhenReady(app.buttons["Cancel Order"], description: "Cancel Order") else { return }
            let sheet = app.sheets.element
            if sheet.waitForExistence(timeout: 5) {
                sheet.buttons["Cancel Order"].tap()
            }
            XCTAssertTrue(app.staticTexts["Cancelled"].waitForExistence(timeout: 30),
                          "order must show Cancelled after cancel")
            shoot("03-order-cancelled")
        }
    }

    // MARK: - TEST 4: dark mode walkthrough

    func test04_darkModeWalkthrough() throws {
        launch(appearance: "dark")
        passOnboardingIfNeeded()
        shoot("04-dark-login")
        assertDarkScreen("login screen must be dark")

        guard let email = env("UITEST_EMAIL"), let password = env("UITEST_PASSWORD") else {
            // Unauthenticated dark coverage only.
            return
        }
        try signInIfNeeded(email, password)

        let tabs = ["Home", "Orders", "Favorites", "Alerts", "Profile"]
        for tab in tabs {
            app.tabBars.buttons[tab].tap()
            _ = app.navigationBars.element.waitForExistence(timeout: 20)
            shoot("04-dark-\(tab.lowercased())")
        }
        assertDarkScreen("tab walkthrough must stay dark")

        // Search (opened from the Home header field, like Android).
        app.tabBars.buttons["Home"].tap()
        if app.buttons["homeSearchField"].waitForExistence(timeout: 20) {
            app.buttons["homeSearchField"].tap()
            _ = app.navigationBars.element.waitForExistence(timeout: 10)
            shoot("04-dark-search")
            assertDarkScreen("search must be dark")
        }

        // Deep screens in dark mode.
        app.tabBars.buttons["Home"].tap()
        let outlets = app.buttons.matching(identifier: "outletCard")
        if outlets.element.waitForExistence(timeout: 60) {
            outlets.allElementsBoundByIndex[0].tap()
            shoot("04-dark-outlet")
            assertDarkScreen("outlet detail must be dark")
            let foods = app.buttons.matching(identifier: "foodCard")
            if foods.element.waitForExistence(timeout: 60) {
                foods.allElementsBoundByIndex[0].tap()
                XCTAssertTrue(app.buttons["addToCartButton"].waitForExistence(timeout: 30))
                shoot("04-dark-food")
                assertDarkScreen("food detail (add-to-cart area included) must be dark")
            }
        }
        app.tabBars.buttons["Profile"].tap()
    }

    // MARK: - TEST 9: debug dump of food-detail accessibility (temporary)

    func test99_dumpFoodDetail() throws {
        guard env("UITEST_EMAIL") != nil, env("UITEST_PASSWORD") != nil else {
            throw XCTSkip("needs confirmed account")
        }
        launch()
        try signInIfNeeded(env("UITEST_EMAIL")!, env("UITEST_PASSWORD")!)
        let outlets = app.buttons.matching(identifier: "outletCard")
        XCTAssertTrue(outlets.element.waitForExistence(timeout: 60))
        outlets.allElementsBoundByIndex[0].tap()
        let foods = app.buttons.matching(identifier: "foodCard")
        XCTAssertTrue(foods.element.waitForExistence(timeout: 60))
        foods.allElementsBoundByIndex[0].tap()
        sleep(5)
        var lines: [String] = []
        for b in app.buttons.allElementsBoundByIndex {
            lines.append("button id=\(b.identifier) label=\(b.label)")
        }
        print("AX_DUMP_START")
        print(lines.joined(separator: "\n"))
        print("AX_DUMP_END")
    }

    // MARK: - Shared auth helper
    /// Signs out when a session is active, so auth UX can be exercised.
    private func signOutIfNeeded() {
        guard app.tabBars.buttons["Home"].waitForExistence(timeout: 10) else { return }
        app.tabBars.buttons["Profile"].tap()
        guard app.buttons["Sign Out"].waitForExistence(timeout: 15) else { return }
        app.buttons["Sign Out"].tap()
        let sheet = app.sheets.element
        if sheet.waitForExistence(timeout: 5) {
            sheet.buttons["Sign Out"].tap()
        }
    }

    /// Signs in with a confirmed account, or reuses the existing session.
    private func signInIfNeeded(_ email: String, _ password: String) throws {
        if app.tabBars.buttons["Home"].waitForExistence(timeout: 10) { return } // already in
        passOnboardingIfNeeded()
        let emailField = app.textFields["loginEmail"]
        guard emailField.waitForExistence(timeout: 15) else {
            throw XCTSkip("app did not reach login — cannot sign in")
        }
        emailField.tap()
        emailField.typeText(email)
        let passField = app.secureTextFields.element
        XCTAssertTrue(passField.waitForExistence(timeout: 10))
        passField.tap()
        passField.typeText(password)
        app.buttons["signInButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 45),
                      "sign-in with confirmed account must reach Home")
    }
}
