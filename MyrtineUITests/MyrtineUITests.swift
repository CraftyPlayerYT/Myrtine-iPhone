import XCTest

final class MyrtineUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-use-mocks", "-sample-data"]
        if name.contains("testCompleteDiagnosticFormAndAutomaticResultOpening") {
            app.launchArguments.append("-prefill-diagnostic")
        }
        if name.contains("testFirstLaunchActivation") {
            app.launchArguments.append("-force-activation")
        }
        app.launch()
        if name.contains("testFirstLaunchActivation") {
            XCTAssertTrue(app.staticTexts["Activer Myrtine"].waitForExistence(timeout: 8))
            XCTAssertEqual(app.windows.firstMatch.frame.width, 428, accuracy: 2)
            XCTAssertEqual(app.windows.firstMatch.frame.height, 926, accuracy: 2)
            capture("50-activation-premier-lancement")
            return
        }
        XCTAssertTrue(app.navigationBars["Myrtine"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.windows.firstMatch.frame.width, 428, accuracy: 2, "Les tests visuels doivent être lancés sur un iPhone 14 Plus en portrait.")
        XCTAssertEqual(app.windows.firstMatch.frame.height, 926, accuracy: 2, "Les tests visuels doivent être lancés sur un iPhone 14 Plus en portrait.")
        capture("01-accueil")
    }

    func testMainAdministrationFlowWithScreenshots() throws {
        app.tabBars.buttons["Diagnostics"].tap()
        capture("02-diagnostics-nouveaux")

        let sampleClient = app.staticTexts["Élodie Martin"]
        XCTAssertTrue(sampleClient.waitForExistence(timeout: 12))
        sampleClient.tap()
        XCTAssertTrue(app.navigationBars["Diagnostic"].waitForExistence(timeout: 5))
        capture("03-diagnostic-detail")

        app.buttons["Fermer"].tap()
        capture("04-retour-diagnostics")

        app.tabBars.buttons["Messagerie"].tap()
        XCTAssertTrue(app.navigationBars["Messagerie"].waitForExistence(timeout: 5))
        capture("05-dossiers-messagerie")

        app.staticTexts["Boîte de réception"].tap()
        capture("06-boite-reception")

        app.staticTexts["Informations complémentaires"].tap()
        XCTAssertTrue(app.navigationBars["Informations complémentaires"].waitForExistence(timeout: 5))
        capture("07-lecture-message")

        app.buttons["Fermer"].tap()
        capture("08-retour-boite-reception")
    }

    func testRichComposerAndDraftActionsWithScreenshots() throws {
        app.tabBars.buttons["Messagerie"].tap()
        app.buttons["Nouveau message"].tap()
        XCTAssertTrue(app.navigationBars["Nouveau message"].waitForExistence(timeout: 5))
        capture("10-compositeur-vide")

        let recipient = app.textFields["compose-recipient"]
        recipient.tap()
        recipient.typeText("client@example.fr")
        capture("11-destinataire-saisi")

        let subject = app.textFields["compose-subject"]
        subject.tap()
        subject.typeText("Essai Myrtine")
        capture("12-objet-saisi")

        let editor = app.textViews["rich-text-editor"]
        editor.tap()
        editor.typeText("Bonjour, ceci est un message de test.")
        capture("13-message-saisi")

        app.buttons["Gras"].tap()
        editor.typeText(" Texte en gras.")
        app.buttons["Gras"].tap()
        capture("14-formatage-gras")

        app.buttons["Couleur du texte"].tap()
        XCTAssertTrue(app.navigationBars["Couleur du texte"].waitForExistence(timeout: 4))
        capture("14a-selecteur-couleur")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Choisir #'")).element(boundBy: 1).tap()
        capture("14b-couleur-selectionnee")
        app.buttons["Appliquer"].tap()
        capture("14c-retour-compositeur")

        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.navigationBars["Messagerie"].waitForExistence(timeout: 5))
        capture("15-brouillon-enregistre")

        app.staticTexts["Brouillons"].tap()
        capture("16-dossier-brouillons")
    }

    func testCompleteDiagnosticFormAndAutomaticResultOpening() throws {
        app.buttons["home-new-diagnostic"].tap()
        XCTAssertTrue(app.navigationBars["Nouveau diagnostic"].waitForExistence(timeout: 5))
        let project = app.textFields["field-Objet du projet"]
        XCTAssertEqual(project.value as? String, "Réduction énergétique de la ligne de production")
        capture("30-nouveau-diagnostic-prerempli")

        let form = app.scrollViews.firstMatch
        form.swipeUp()
        capture("31-projet-complet")
        form.swipeUp()
        capture("32-depenses-completes")
        form.swipeUp()
        XCTAssertTrue(app.textFields["field-Adresse e-mail"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["field-Adresse e-mail"].value as? String, "camille@example.fr")
        capture("33-contact-complet")

        let submit = app.buttons["diagnostic-submit"]
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.navigationBars["Diagnostic"].waitForExistence(timeout: 10))
        capture("44-resultat-ouvert-automatiquement")

        let detail = app.scrollViews.firstMatch
        let resultTitle = app.staticTexts["Résultat"]
        for _ in 0..<5 where !resultTitle.isHittable {
            detail.swipeUp()
        }
        XCTAssertTrue(resultTitle.isHittable)
        detail.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["diagnostic-result-table"].waitForExistence(timeout: 5))
        capture("45-resultat-markdown-rendu")
    }

    func testAirplaneModeKeepsLocalAppUsable() throws {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-use-mocks", "-sample-data", "-network-offline"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Hors ligne — vos modifications sont enregistrées sur cet iPhone"].waitForExistence(timeout: 5))
        capture("20-mode-avion-accueil")

        app.tabBars.buttons["Clients"].tap()
        XCTAssertTrue(app.staticTexts["Élodie Martin"].waitForExistence(timeout: 5))
        capture("21-mode-avion-clients")

        app.tabBars.buttons["Diagnostics"].tap()
        capture("22-mode-avion-diagnostics")
    }

    func testFirstLaunchActivationIsServerDriven() throws {
        let code = app.secureTextFields["activation-code"]
        code.tap()
        code.typeText("TEST-CODE")
        app.buttons["activation-submit"].tap()
        XCTAssertTrue(app.navigationBars["Myrtine"].waitForExistence(timeout: 8))
        capture("51-activation-terminee")
    }

    func testTrashDoesNotOfferMessageComposition() throws {
        app.tabBars.buttons["Messagerie"].tap()
        XCTAssertTrue(app.staticTexts["Corbeille"].waitForExistence(timeout: 5))
        app.staticTexts["Corbeille"].tap()
        XCTAssertTrue(app.navigationBars["Corbeille"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Nouveau message"].exists)
        capture("52-corbeille-sans-composition")
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.45)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
