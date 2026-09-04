import Foundation
import SwiftData

@MainActor
final class LocalStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        context.autosaveEnabled = true
    }

    func save() throws { try context.save() }

    func diagnostics(includeDeleted: Bool = false) -> [DiagnosticRecord] {
        let rows = (try? context.fetch(FetchDescriptor<DiagnosticRecord>())) ?? []
        return rows
            .filter { includeDeleted || !$0.isTrashed }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func diagnostic(id: String) -> DiagnosticRecord? {
        diagnostics(includeDeleted: true).first { $0.id == id }
    }

    func insert(_ diagnostic: DiagnosticRecord) throws {
        diagnostic.updatedAt = .now
        diagnostic.syncRequired = true
        context.insert(diagnostic)
        try upsertClient(from: diagnostic)
        try enqueue(operation: "upsert_diagnostic", entityID: diagnostic.id)
    }

    func upsertRemoteDiagnostic(_ remote: DiagnosticSnapshot) throws {
        if let existing = diagnostic(id: remote.id) {
            guard remote.updatedAt > existing.updatedAt, !existing.syncRequired else { return }
            existing.createdAt = remote.createdAt
            existing.updatedAt = remote.updatedAt
            existing.deletedAt = remote.deletedAt
            existing.stateRaw = remote.state
            existing.projectObject = remote.projectObject
            existing.projectOwner = remote.projectOwner
            existing.sector = remote.sector
            existing.location = remote.location
            existing.workforce = remote.workforce
            existing.revenue = remote.revenue
            existing.budget = remote.budget
            existing.schedule = remote.schedule
            existing.expenses = remote.expenses
            existing.additionalInformation = remote.additionalInformation
            existing.lastName = remote.lastName
            existing.firstName = remote.firstName
            existing.email = remote.email
            existing.phone = remote.phone
            existing.resultMarkdown = remote.resultMarkdown
            existing.lastError = remote.lastError
            existing.isTrashed = remote.isDeleted
            existing.isRead = remote.isRead
        } else {
            let incoming = DiagnosticRecord(
                id: remote.id,
                createdAt: remote.createdAt,
                updatedAt: remote.updatedAt,
                state: DiagnosticState(rawValue: remote.state) ?? .received,
                projectObject: remote.projectObject,
                projectOwner: remote.projectOwner,
                sector: remote.sector,
                location: remote.location,
                workforce: remote.workforce,
                revenue: remote.revenue,
                budget: remote.budget,
                schedule: remote.schedule,
                expenses: remote.expenses,
                additionalInformation: remote.additionalInformation,
                lastName: remote.lastName,
                firstName: remote.firstName,
                email: remote.email,
                phone: remote.phone
            )
            incoming.deletedAt = remote.deletedAt
            incoming.resultMarkdown = remote.resultMarkdown
            incoming.lastError = remote.lastError
            incoming.isTrashed = remote.isDeleted
            incoming.isRead = remote.isRead
            context.insert(incoming)
            try upsertClient(from: incoming)
        }
        try save()
    }

    func markDiagnosticRead(_ diagnostic: DiagnosticRecord) throws {
        diagnostic.isRead = true
        diagnostic.updatedAt = .now
        diagnostic.syncRequired = true
        try enqueue(operation: "upsert_diagnostic", entityID: diagnostic.id)
    }

    func moveDiagnosticToTrash(_ diagnostic: DiagnosticRecord) throws {
        diagnostic.isTrashed = true
        diagnostic.deletedAt = .now
        diagnostic.state = .deleted
        diagnostic.updatedAt = .now
        diagnostic.syncRequired = true
        try enqueue(operation: "upsert_diagnostic", entityID: diagnostic.id)
    }

    func restoreDiagnostic(_ diagnostic: DiagnosticRecord) throws {
        diagnostic.isTrashed = false
        diagnostic.deletedAt = nil
        diagnostic.state = diagnostic.resultMarkdown.isEmpty ? .draft : .received
        diagnostic.updatedAt = .now
        diagnostic.syncRequired = true
        try enqueue(operation: "upsert_diagnostic", entityID: diagnostic.id)
    }

    func clients() -> [ClientRecord] {
        ((try? context.fetch(FetchDescriptor<ClientRecord>())) ?? [])
            .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    func upsertClient(from diagnostic: DiagnosticRecord) throws {
        let normalizedEmail = diagnostic.email.lowercased()
        guard !normalizedEmail.isEmpty else { return }
        if let existing = clients().first(where: { $0.email == normalizedEmail }) {
            existing.lastName = diagnostic.lastName
            existing.firstName = diagnostic.firstName
            existing.phone = diagnostic.phone
            existing.company = diagnostic.projectOwner
            existing.updatedAt = .now
        } else {
            context.insert(ClientRecord(lastName: diagnostic.lastName, firstName: diagnostic.firstName, email: normalizedEmail, phone: diagnostic.phone, company: diagnostic.projectOwner))
        }
    }

    func upsertClient(_ remote: ClientSnapshot) throws {
        if let existing = clients().first(where: { $0.email == remote.email.lowercased() }) {
            guard remote.updatedAt > existing.updatedAt else { return }
            existing.lastName = remote.lastName
            existing.firstName = remote.firstName
            existing.phone = remote.phone
            existing.company = remote.company
            existing.notes = remote.notes
            existing.updatedAt = remote.updatedAt
        } else {
            context.insert(ClientRecord(id: remote.id, createdAt: remote.createdAt, updatedAt: remote.updatedAt, lastName: remote.lastName, firstName: remote.firstName, email: remote.email, phone: remote.phone, company: remote.company, notes: remote.notes))
        }
        try save()
    }

    func folders(includeDeleted: Bool = false) -> [MailFolderRecord] {
        ((try? context.fetch(FetchDescriptor<MailFolderRecord>())) ?? [])
            .filter { includeDeleted || !$0.isTrashed }
            .sorted {
                if $0.sortOrder == $1.sortOrder { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return $0.sortOrder < $1.sortOrder
            }
    }

    func folder(named name: String) -> MailFolderRecord? {
        folders(includeDeleted: true).first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func createFolder(name: String) throws -> MailFolderRecord {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw StoreError.invalidName }
        guard folder(named: cleanName) == nil else { throw StoreError.duplicateName }
        let folder = MailFolderRecord(name: cleanName, sortOrder: 100 + folders(includeDeleted: true).count)
        context.insert(folder)
        try enqueue(operation: "upsert_folder", entityID: folder.id)
        return folder
    }

    func upsertRemoteFolder(name: String, kind: String, sortOrder: Int, createdAt: Date, updatedAt: Date, isDeleted: Bool, previousName: String) throws {
        if let existing = folder(named: name) {
            guard updatedAt > existing.updatedAt else { return }
            existing.kind = kind
            existing.sortOrder = sortOrder
            existing.updatedAt = updatedAt
            existing.systemImage = Self.systemImage(for: kind)
            existing.isTrashed = isDeleted
            existing.previousName = previousName
        } else {
            context.insert(MailFolderRecord(name: name, systemImage: Self.systemImage(for: kind), kind: kind, sortOrder: sortOrder, createdAt: createdAt, updatedAt: updatedAt, isTrashed: isDeleted, previousName: previousName))
        }
        try save()
    }

    private static func systemImage(for kind: String) -> String {
        switch kind {
        case "inbox": "tray"
        case "priority": "star"
        case "drafts": "doc.text"
        case "sent": "paperplane"
        case "archive": "archivebox"
        case "trash", "deleted": "trash"
        default: "folder"
        }
    }

    func renameFolder(_ folder: MailFolderRecord, to name: String) throws {
        guard folder.kind == "custom" else { throw StoreError.systemFolder }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw StoreError.invalidName }
        guard self.folder(named: cleanName) == nil else { throw StoreError.duplicateName }
        let oldName = folder.name
        let containedMessages = messages(in: oldName, includeDeleted: true)

        folder.previousName = oldName
        folder.name = cleanName
        folder.updatedAt = .now
        for message in containedMessages {
            message.folderName = cleanName
            message.updatedAt = .now
            message.syncRequired = true
        }
        try save()
        try enqueue(operation: "rename_folder", entityID: folder.id)
    }

    func moveFolderToTrash(_ folder: MailFolderRecord) throws {
        guard folder.kind == "custom" else { throw StoreError.systemFolder }
        let folderName = folder.name
        let containedMessages = messages(in: folderName, includeDeleted: true)

        folder.previousName = folderName
        folder.isTrashed = true
        folder.updatedAt = .now
        for message in containedMessages {
            message.previousFolderName = folderName
            message.folderName = "Corbeille"
            message.isTrashed = true
            message.updatedAt = .now
            message.syncRequired = true
        }
        try save()
        try enqueue(operation: "upsert_folder", entityID: folder.id)
    }

    func restoreFolder(_ folder: MailFolderRecord) throws {
        let restoredName = folder.previousName.isEmpty ? folder.name : folder.previousName
        let containedMessages = messages(includeDeleted: true).filter { $0.previousFolderName == restoredName }

        folder.isTrashed = false
        folder.updatedAt = .now
        folder.name = restoredName
        for message in containedMessages {
            message.folderName = restoredName
            message.previousFolderName = ""
            message.isTrashed = false
            message.updatedAt = .now
            message.syncRequired = true
        }
        try save()
        try enqueue(operation: "upsert_folder", entityID: folder.id)
    }

    func messages(in folderName: String? = nil, includeDeleted: Bool = false) -> [MailMessageRecord] {
        ((try? context.fetch(FetchDescriptor<MailMessageRecord>())) ?? [])
            .filter { row in
                (folderName == nil || row.folderName == folderName) && (includeDeleted || !row.isTrashed)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func message(id: String) -> MailMessageRecord? {
        messages(includeDeleted: true).first { $0.id == id }
    }

    func saveMessage(_ message: MailMessageRecord, queue: Bool = true) throws {
        if self.message(id: message.id) == nil { context.insert(message) }
        message.updatedAt = .now
        message.syncRequired = queue
        if queue { try enqueue(operation: "upsert_message", entityID: message.id) }
        try save()
    }

    func moveMessage(_ message: MailMessageRecord, to folderName: String) throws {
        message.previousFolderName = message.folderName
        message.folderName = folderName
        message.isTrashed = folderName == "Corbeille"
        message.updatedAt = .now
        message.syncRequired = true
        try enqueue(operation: "upsert_message", entityID: message.id)
    }

    func restoreMessage(_ message: MailMessageRecord) throws {
        message.folderName = message.previousFolderName.isEmpty ? "Boîte de réception" : message.previousFolderName
        message.previousFolderName = ""
        message.isTrashed = false
        message.updatedAt = .now
        message.syncRequired = true
        try enqueue(operation: "upsert_message", entityID: message.id)
    }

    func deletePermanently(_ message: MailMessageRecord) throws {
        context.delete(message)
        try enqueue(operation: "delete_message", entityID: message.id)
    }

    func upsertRemoteMessage(_ remote: MailSnapshot) throws {
        if let existing = message(id: remote.id) {
            guard remote.updatedAt > existing.updatedAt, !existing.syncRequired else { return }
            existing.folderName = remote.folderName
            existing.createdAt = remote.createdAt
            existing.updatedAt = remote.updatedAt
            existing.direction = remote.direction
            existing.sender = remote.sender
            existing.recipient = remote.recipient
            existing.subject = remote.subject
            existing.body = remote.body
            existing.htmlBody = remote.htmlBody
            existing.isRead = remote.isRead
            existing.isTrashed = remote.isDeleted
            existing.previousFolderName = remote.previousFolderName
        } else {
            context.insert(MailMessageRecord(id: remote.id, folderName: remote.folderName, previousFolderName: remote.previousFolderName, createdAt: remote.createdAt, updatedAt: remote.updatedAt, direction: remote.direction, sender: remote.sender, recipient: remote.recipient, subject: remote.subject, body: remote.body, htmlBody: remote.htmlBody, isRead: remote.isRead, isTrashed: remote.isDeleted))
        }
        try save()
    }

    func logs() -> [LogRecord] {
        ((try? context.fetch(FetchDescriptor<LogRecord>())) ?? []).sorted { $0.date > $1.date }
    }

    func log(level: String = "Information", category: String, message: String, detail: String = "") {
        context.insert(LogRecord(level: level, category: category, message: message, detail: detail))
        try? save()
    }

    func pendingOperations() -> [PendingOperationRecord] {
        ((try? context.fetch(FetchDescriptor<PendingOperationRecord>())) ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func enqueue(operation: String, entityID: String) throws {
        if let existing = pendingOperations().first(where: { $0.operation == operation && $0.entityID == entityID }) {
            existing.lastError = ""
        } else {
            context.insert(PendingOperationRecord(operation: operation, entityID: entityID))
        }
        try save()
    }

    func complete(_ operation: PendingOperationRecord) throws {
        context.delete(operation)
        try save()
    }

    func seedSystemFolders() {
        let systemFolders: [(String, String, String, Int)] = [
            ("Boîte de réception", "tray", "inbox", 0),
            ("Prioritaires", "star", "priority", 1),
            ("Brouillons", "doc.text", "drafts", 2),
            ("Éléments envoyés", "paperplane", "sent", 3),
            ("Archives", "archivebox", "archive", 4),
            ("Corbeille", "trash", "trash", 5)
        ]
        for item in systemFolders where folder(named: item.0) == nil {
            context.insert(MailFolderRecord(name: item.0, systemImage: item.1, kind: item.2, sortOrder: item.3))
        }
        try? save()
    }

    func seedPreviewData() {
        guard diagnostics(includeDeleted: true).isEmpty else { return }
        let diagnostic = DiagnosticRecord(
            projectObject: "Modernisation énergétique de la ligne de production",
            projectOwner: "Atelier des Baous",
            sector: "Agroalimentaire",
            location: "Grasse, Alpes-Maritimes",
            workforce: "8 salariés",
            revenue: "1 150 000 €",
            budget: "240 000 € HT",
            schedule: "Installation au premier trimestre 2027",
            expenses: ["Machines moins énergivores", "Récupération de chaleur", "Formation"],
            lastName: "Martin",
            firstName: "Élodie",
            email: "elodie.martin@example.fr",
            phone: "06 12 34 56 78"
        )
        diagnostic.state = .received
        diagnostic.resultMarkdown = SampleData.diagnosticMarkdown
        context.insert(diagnostic)
        try? upsertClient(from: diagnostic)
        let incoming = MailMessageRecord(folderName: "Boîte de réception", direction: "received", sender: "elodie.martin@example.fr", recipient: "contact@myrtine.fr", subject: "Informations complémentaires", body: "Bonjour, je vous joins les précisions demandées concernant notre projet.", isRead: false)
        context.insert(incoming)
        try? save()
    }

    enum StoreError: LocalizedError {
        case invalidName, duplicateName, systemFolder
        var errorDescription: String? {
            switch self {
            case .invalidName: "Le nom du dossier est vide."
            case .duplicateName: "Un dossier porte déjà ce nom."
            case .systemFolder: "Les dossiers système ne peuvent pas être renommés ou supprimés."
            }
        }
    }
}

struct ClientSnapshot: Sendable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let lastName: String
    let firstName: String
    let email: String
    let phone: String
    let company: String
    let notes: String
}

struct DiagnosticSnapshot: Sendable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let state: String
    let projectObject: String
    let projectOwner: String
    let sector: String
    let location: String
    let workforce: String
    let revenue: String
    let budget: String
    let schedule: String
    let expenses: [String]
    let additionalInformation: String
    let lastName: String
    let firstName: String
    let email: String
    let phone: String
    let resultMarkdown: String
    let lastError: String
    let isDeleted: Bool
    let isRead: Bool
}

struct MailSnapshot: Sendable {
    let id: String
    let folderName: String
    let createdAt: Date
    let updatedAt: Date
    let direction: String
    let sender: String
    let recipient: String
    let subject: String
    let body: String
    let htmlBody: String
    let isRead: Bool
    let isDeleted: Bool
    let previousFolderName: String
}

enum SampleData {
    static let diagnosticMarkdown = """
    # Diagnostic de financement

    Les dispositifs ci-dessous ont été vérifiés à partir de sources officielles.

    | Organisme financeur | Dispositif | Subvention mobilisable | Critères principaux | Échéance | Cahier des charges |
    |---|---|---|---|---|---|
    | ADEME | Fonds Chaleur | 20 % à 60 % des dépenses éligibles | Installation de chaleur renouvelable, étude préalable | Au fil de l'eau | [Consulter](https://agirpourlatransition.ademe.fr) |
    | Région Sud | Transition écologique des entreprises | Selon l'assiette du projet | PME implantée en Provence-Alpes-Côte d'Azur | À vérifier | |

    ## Démarches prioritaires

    1. Confirmer l'éligibilité technique avec l'ADEME.
    2. Préparer les devis et le calendrier d'investissement.
    3. Ne signer aucun bon de commande avant le dépôt si le règlement l'interdit.
    """
}
