import XCTest

@MainActor
final class MyrtineUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-use-mocks", "-sample-data"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Myrtine"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.windows.firstMatch.frame.width, 428, accuracy: 2, "Les tests visuels doivent être lancés sur un iPhone 14 Plus en portrait.")
        XCTAssertEqual(app.windows.firstMatch.frame.height, 926, accuracy: 2, "Les tests visuels doivent être lancés sur un iPhone 14 Plus en portrait.")
        capture("01-accueil")
    }

    func testMainAdministrationFlowWithScreenshots() throws {
        app.tabBars.buttons["Diagnostics"].tap()
        capture("02-diagnostics-nouveaux")

        let sampleClient = app.buttons["diagnostic-open-elodie.martin@example.fr"]
        XCTAssertTrue(sampleClient.waitForExistence(timeout: 5))
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
        capture("30-nouveau-diagnostic-vide")

        enter("Réduction énergétique de la ligne de production", in: "field-Objet du projet", screenshot: "31-objet-projet")
        enter("Atelier Test iOS", in: "field-Porteur du projet", screenshot: "32-porteur-projet")
        enter("Industrie manufacturière", in: "field-Secteur d'activité", screenshot: "33-secteur")
        enter("Lyon, Auvergne-Rhône-Alpes", in: "field-Localisation", screenshot: "34-localisation")
        enter("12 salariés", in: "field-Effectif", screenshot: "35-effectif")
        enter("900 000 €", in: "field-Chiffre d'affaires", screenshot: "36-chiffre-affaires")
        enter("150 000 € HT", in: "field-Budget prévisionnel", screenshot: "37-budget")
        enter("Deuxième trimestre 2027", in: "field-Calendrier", screenshot: "38-calendrier")

        let expense = app.textFields["diagnostic-expense"]
        var expenseScrolls = 0
        while !expense.isHittable && expenseScrolls < 5 { app.swipeUp(); expenseScrolls += 1 }
        XCTAssertTrue(expense.isHittable)
        expense.tap(); expense.typeText("Machines moins énergivores")
        app.buttons["Ajouter la dépense"].tap()
        capture("39-depense-ajoutee")

        enter("Camille", in: "field-Prénom", screenshot: "40-prenom")
        enter("Martin", in: "field-Nom", screenshot: "41-nom")
        enter("camille@example.fr", in: "field-Adresse e-mail", screenshot: "42-email")
        enter("0600000000", in: "field-Téléphone", screenshot: "43-telephone")

        app.buttons["diagnostic-submit"].tap()
        XCTAssertTrue(app.navigationBars["Diagnostic"].waitForExistence(timeout: 10))
        capture("44-resultat-ouvert-automatiquement")
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

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func enter(_ value: String, in identifier: String, screenshot: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Champ introuvable : \(identifier)")
        var attempts = 0
        while !field.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(field.isHittable, "Champ non accessible : \(identifier)")
        field.tap()
        let focus = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"),
            object: field
        )
        if XCTWaiter.wait(for: [focus], timeout: 2) != .completed {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        field.typeText(value)
        capture(screenshot)
    }
}
