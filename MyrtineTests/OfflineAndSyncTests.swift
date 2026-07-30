import XCTest
@testable import Myrtine

@MainActor
final class OfflineAndSyncTests: XCTestCase {
    func testActivationTokenCanBePersistedOnSimulator() throws {
        #if targetEnvironment(simulator)
        let account = "activation-test-\(UUID().uuidString)"
        defer { KeychainStore.remove(account) }

        try KeychainStore.set("verified-token", for: account)

        XCTAssertEqual(KeychainStore.get(account), "verified-token")
        KeychainStore.remove(account)
        XCTAssertNil(KeychainStore.get(account))
        #endif
    }

    func testActivationCodeFormatterAddsVisibleSeparators() {
        XCTAssertEqual(ActivationCodeFormatter.format("060213"), "060213")
        XCTAssertEqual(ActivationCodeFormatter.format("0602131"), "060213-1")
        XCTAssertEqual(ActivationCodeFormatter.format("060213121215061222"), "060213-121215-061222")
        XCTAssertEqual(ActivationCodeFormatter.format("060213-121215-061222999"), "060213-121215-061222")
        XCTAssertTrue(ActivationCodeFormatter.isComplete("060213121215061222"))
        XCTAssertFalse(ActivationCodeFormatter.isComplete("060213121215"))
    }

    func testActivationTokenNamespaceInvalidatesPreReleaseToken() {
        XCTAssertEqual(MyrtineAPIClient.legacyActivationTokenAccount, "iphone-activation-token")
        XCTAssertEqual(MyrtineAPIClient.activationTokenAccount, "iphone-activation-token-v2")
        XCTAssertNotEqual(MyrtineAPIClient.activationTokenAccount, MyrtineAPIClient.legacyActivationTokenAccount)
    }

    func testOfflineDiagnosticIsQueuedWithoutNetworkCall() async throws {
        let environment = AppEnvironment(inMemory: true, useMocks: true)
        environment.network.simulation = .offline
        let diagnostic = completeDiagnostic()
        try environment.store.insert(diagnostic)

        try await environment.sync.submit(diagnostic)

        XCTAssertEqual(diagnostic.state, .queued)
        XCTAssertTrue(diagnostic.syncRequired)
        XCTAssertEqual(environment.store.pendingOperations().filter { $0.operation == "send_diagnostic" }.count, 1)
    }

    func testMockDiagnosticReturnsReadableMarkdown() async throws {
        let environment = AppEnvironment(inMemory: true, useMocks: true)
        environment.network.simulation = .online
        let diagnostic = completeDiagnostic()
        try environment.store.insert(diagnostic)

        try await environment.sync.submit(diagnostic)

        XCTAssertEqual(diagnostic.state, .received)
        XCTAssertTrue(diagnostic.resultMarkdown.contains("| Organisme financeur |"))
        XCTAssertEqual(diagnostic.aiProvider, "Simulation")
    }

    func testDeletedFolderKeepsAndRestoresItsMessages() throws {
        let environment = AppEnvironment(inMemory: true, useMocks: true)
        environment.store.seedSystemFolders()
        let folder = try environment.store.createFolder(name: "Entreprise Test")
        let message = MailMessageRecord(folderName: folder.name, direction: "received", sender: "client@example.fr", recipient: "contact@myrtine.fr", subject: "Test", body: "Bonjour")
        try environment.store.saveMessage(message, queue: false)

        try environment.store.renameFolder(folder, to: "Entreprise Renommée")
        XCTAssertEqual(folder.name, "Entreprise Renommée")
        XCTAssertEqual(message.folderName, "Entreprise Renommée")

        try environment.store.moveFolderToTrash(folder)
        XCTAssertTrue(folder.isTrashed)
        XCTAssertEqual(message.folderName, "Corbeille")
        XCTAssertEqual(message.previousFolderName, "Entreprise Renommée")

        try environment.store.restoreFolder(folder)
        XCTAssertFalse(folder.isTrashed)
        XCTAssertEqual(folder.name, "Entreprise Renommée")
        XCTAssertEqual(message.folderName, "Entreprise Renommée")
        XCTAssertEqual(message.previousFolderName, "")
        XCTAssertFalse(message.isTrashed)
    }

    private func completeDiagnostic() -> DiagnosticRecord {
        DiagnosticRecord(projectObject: "Réduire la consommation énergétique", projectOwner: "Atelier Test", sector: "Industrie", location: "Lyon", workforce: "12 salariés", revenue: "900 000 €", budget: "150 000 €", schedule: "2027", expenses: ["Machines"], lastName: "Martin", firstName: "Camille", email: "camille@example.fr", phone: "0600000000")
    }
}
