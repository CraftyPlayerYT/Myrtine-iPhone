import XCTest
@testable import Myrtine

@MainActor
final class OfflineAndSyncTests: XCTestCase {
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
        XCTAssertTrue(folder.isDeleted)
        XCTAssertEqual(message.folderName, "Corbeille")
        XCTAssertEqual(message.previousFolderName, "Entreprise Renommée")

        try environment.store.restoreFolder(folder)
        XCTAssertFalse(folder.isDeleted)
        XCTAssertEqual(folder.name, "Entreprise Renommée")
        XCTAssertEqual(message.folderName, "Entreprise Renommée")
        XCTAssertEqual(message.previousFolderName, "")
        XCTAssertFalse(message.isDeleted)
    }

    private func completeDiagnostic() -> DiagnosticRecord {
        DiagnosticRecord(projectObject: "Réduire la consommation énergétique", projectOwner: "Atelier Test", sector: "Industrie", location: "Lyon", workforce: "12 salariés", revenue: "900 000 €", budget: "150 000 €", schedule: "2027", expenses: ["Machines"], lastName: "Martin", firstName: "Camille", email: "camille@example.fr", phone: "0600000000")
    }
}
