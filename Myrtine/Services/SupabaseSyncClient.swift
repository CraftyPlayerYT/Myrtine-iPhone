import Foundation

@MainActor
final class SupabaseSyncClient {
    private let network: NetworkMonitor
    private let store: LocalStore
    private let api: MyrtineAPIClient
    private let useMocks: Bool

    init(network: NetworkMonitor, store: LocalStore, api: MyrtineAPIClient, useMocks: Bool) {
        self.network = network
        self.store = store
        self.api = api
        self.useMocks = useMocks
    }

    func pullAll() async throws {
        guard network.isOnline else { throw APIError.offline }
        if useMocks { return }
        let snapshot: SyncSnapshotResponse = try await api.postServer(ActionRequest(action: "sync_snapshot"))
        for row in snapshot.diagnostics { try store.upsertRemoteDiagnostic(row.snapshot) }
        for row in snapshot.clients { try store.upsertClient(row.snapshot) }
        for row in snapshot.folders {
            try store.upsertRemoteFolder(name: row.name, kind: row.kind, sortOrder: row.sortOrder, createdAt: row.createdAt, updatedAt: row.updatedAt, isDeleted: row.isDeleted ?? false, previousName: row.previousName ?? "")
        }
        for row in snapshot.messages { try store.upsertRemoteMessage(row.snapshot) }
    }

    func pushDiagnostic(_ diagnostic: DiagnosticRecord) async throws {
        if useMocks {
            diagnostic.syncRequired = false
            try store.save()
            return
        }
        let _: BasicResponse = try await api.postServer(RecordRequest(action: "upsert_diagnostic", record: RemoteDiagnostic(diagnostic)))
        diagnostic.syncRequired = false
        try store.save()
    }

    func pushClient(_ client: ClientRecord) async throws {
        _ = client
    }

    func pushFolder(_ folder: MailFolderRecord) async throws {
        if useMocks {
            if !folder.isTrashed { folder.previousName = "" }
            try store.save()
            return
        }
        let _: BasicResponse = try await api.postServer(RecordRequest(action: "upsert_folder", record: RemoteFolder(folder)))
        if !folder.isTrashed {
            folder.previousName = ""
            try store.save()
        }
    }

    func pushMessage(_ message: MailMessageRecord) async throws {
        if useMocks {
            message.syncRequired = false
            try store.save()
            return
        }
        let _: BasicResponse = try await api.postServer(RecordRequest(action: "upsert_message", record: RemoteMail(message)))
        message.syncRequired = false
        try store.save()
    }

    func deleteMessage(id: String) async throws {
        if useMocks { return }
        let _: BasicResponse = try await api.postServer(DeleteRequest(action: "delete_message", id: id))
    }
}

private struct ActionRequest: Encodable { let action: String }
private struct DeleteRequest: Encodable { let action: String; let id: String }
private struct RecordRequest<Record: Encodable>: Encodable { let action: String; let record: Record }
private struct BasicResponse: Decodable { let state: String; enum CodingKeys: String, CodingKey { case state = "etat_de_la_requete" } }
private struct SyncSnapshotResponse: Decodable {
    let diagnostics: [RemoteDiagnostic]
    let clients: [RemoteClient]
    let folders: [RemoteFolder]
    let messages: [RemoteMail]
    enum CodingKeys: String, CodingKey {
        case diagnostics, clients
        case folders = "mail_folders"
        case messages = "mail_messages"
    }
}

private struct RemoteDiagnostic: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let status: String
    let title: String?
    let projectObject: String
    let projectOwner: String
    let sector: String
    let location: String
    let workforce: String
    let revenue: String
    let budget: String
    let schedule: String
    let expensesJSON: String
    let additionalInformation: String
    let lastName: String
    let firstName: String
    let email: String
    let phone: String
    let resultMarkdown: String?
    let lastError: String?
    let isDeleted: Bool?
    let syncRequired: Bool
    let isRead: Bool

    init(_ value: DiagnosticRecord) {
        id = value.id
        createdAt = value.createdAt
        updatedAt = value.updatedAt
        deletedAt = value.deletedAt
        status = value.stateRaw
        title = value.title
        projectObject = value.projectObject
        projectOwner = value.projectOwner
        sector = value.sector
        location = value.location
        workforce = value.workforce
        revenue = value.revenue
        budget = value.budget
        schedule = value.schedule
        expensesJSON = String(data: (try? JSONEncoder().encode(value.expenses)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        additionalInformation = value.additionalInformation
        lastName = value.lastName
        firstName = value.firstName
        email = value.email
        phone = value.phone
        resultMarkdown = value.resultMarkdown
        lastError = value.lastError
        isDeleted = value.isTrashed
        syncRequired = false
        isRead = value.isRead
    }

    var snapshot: DiagnosticSnapshot {
        DiagnosticSnapshot(id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, state: status, title: title ?? projectObject, projectObject: projectObject, projectOwner: projectOwner, sector: sector, location: location, workforce: workforce, revenue: revenue, budget: budget, schedule: schedule, expenses: (try? JSONDecoder().decode([String].self, from: Data(expensesJSON.utf8))) ?? [], additionalInformation: additionalInformation, lastName: lastName, firstName: firstName, email: email, phone: phone, resultMarkdown: resultMarkdown ?? "", lastError: lastError ?? "", isDeleted: isDeleted ?? false, isRead: isRead)
    }

    enum CodingKeys: String, CodingKey {
        case id, status, title = "titre", sector = "secteur", location = "localisation", workforce = "effectif", schedule = "calendrier", email
        case createdAt = "created_at", updatedAt = "updated_at", deletedAt = "deleted_at"
        case projectObject = "objet_projet", projectOwner = "porteur_projet", revenue = "chiffre_affaires", budget = "budget_previsionnel"
        case expensesJSON = "depenses_json", additionalInformation = "informations_supplementaires", lastName = "nom", firstName = "prenom", phone = "telephone"
        case resultMarkdown = "server_message", lastError = "last_error", isDeleted = "is_deleted", syncRequired = "sync_required", isRead = "is_read"
    }
}

private struct RemoteClient: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let lastName: String
    let firstName: String
    let email: String
    let phone: String
    let company: String?
    let notes: String?

    init(_ value: ClientRecord) {
        id = value.id; createdAt = value.createdAt; updatedAt = value.updatedAt; lastName = value.lastName; firstName = value.firstName; email = value.email; phone = value.phone; company = value.company; notes = value.notes
    }
    var snapshot: ClientSnapshot { ClientSnapshot(id: id, createdAt: createdAt, updatedAt: updatedAt, lastName: lastName, firstName: firstName, email: email, phone: phone, company: company ?? "", notes: notes ?? "") }
    enum CodingKeys: String, CodingKey {
        case id, email, notes
        case createdAt = "created_at", updatedAt = "updated_at", lastName = "nom", firstName = "prenom", phone = "telephone", company = "entreprise"
    }
}

private struct RemoteFolder: Codable {
    let name: String
    let kind: String
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool
    let previousName: String?

    init(_ value: MailFolderRecord) {
        name = value.name; kind = value.kind; sortOrder = value.sortOrder; createdAt = value.createdAt; updatedAt = value.updatedAt; isDeleted = value.isTrashed; previousName = value.previousName.isEmpty ? nil : value.previousName
    }
    enum CodingKeys: String, CodingKey { case name, kind; case sortOrder = "sort_order", createdAt = "created_at", updatedAt = "updated_at", isDeleted = "is_deleted", previousName = "previous_name" }
}

private struct RemoteMail: Codable {
    let id: String
    let folderName: String
    let createdAt: Date
    let updatedAt: Date
    let direction: String
    let sender: String
    let recipient: String
    let subject: String
    let body: String
    let htmlBody: String?
    let isRead: Bool
    let isDeleted: Bool?
    let previousFolderName: String?

    init(_ value: MailMessageRecord) {
        id = value.id; folderName = value.folderName; createdAt = value.createdAt; updatedAt = value.updatedAt; direction = value.direction; sender = value.sender; recipient = value.recipient; subject = value.subject; body = value.body; htmlBody = value.htmlBody; isRead = value.isRead; isDeleted = value.isTrashed; previousFolderName = value.previousFolderName.isEmpty ? nil : value.previousFolderName
    }
    var snapshot: MailSnapshot { MailSnapshot(id: id, folderName: folderName, createdAt: createdAt, updatedAt: updatedAt, direction: direction, sender: sender, recipient: recipient, subject: subject, body: body, htmlBody: htmlBody ?? "", isRead: isRead, isDeleted: isDeleted ?? false, previousFolderName: previousFolderName ?? "") }
    enum CodingKeys: String, CodingKey {
        case id, direction, sender, recipient, subject, body
        case folderName = "folder_name", createdAt = "created_at", updatedAt = "updated_at", htmlBody = "html_body", isRead = "is_read", isDeleted = "is_deleted", previousFolderName = "previous_folder_name"
    }
}

extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let regular = ISO8601DateFormatter()
            if let date = regular.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date ISO 8601 invalide: \(value)")
        }
        return decoder
    }
}
