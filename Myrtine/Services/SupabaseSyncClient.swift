import Foundation

@MainActor
final class SupabaseSyncClient {
    private static let baseURL = URL(string: "https://jfwpcephqoebjrcwsxbk.supabase.co/rest/v1")!
    private static let publishableKey = "sb_publishable_AUoaW8ZwVnh-VXuZGuoy3g_f355SCB_"

    private let network: NetworkMonitor
    private let store: LocalStore
    private let session: URLSession
    private let useMocks: Bool

    init(network: NetworkMonitor, store: LocalStore, useMocks: Bool) {
        self.network = network
        self.store = store
        self.useMocks = useMocks
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func pullAll() async throws {
        guard network.isOnline else { throw APIError.offline }
        if useMocks { return }
        async let diagnostics: [RemoteDiagnostic] = get("diagnostics?select=*")
        async let clients: [RemoteClient] = get("clients?select=*")
        async let folders: [RemoteFolder] = get("mail_folders?select=name,kind,sort_order,created_at,updated_at")
        async let messages: [RemoteMail] = get("mail_messages?select=*")

        let downloadedDiagnostics = try await diagnostics
        for row in downloadedDiagnostics { try store.upsertRemoteDiagnostic(row.snapshot) }
        let downloadedClients = try await clients
        for row in downloadedClients { try store.upsertClient(row.snapshot) }
        let downloadedFolders = try await folders
        for row in downloadedFolders {
            try store.upsertRemoteFolder(name: row.name, kind: row.kind, sortOrder: row.sortOrder, createdAt: row.createdAt, updatedAt: row.updatedAt)
        }
        let downloadedMessages = try await messages
        for row in downloadedMessages { try store.upsertRemoteMessage(row.snapshot) }
    }

    func pushDiagnostic(_ diagnostic: DiagnosticRecord) async throws {
        try await upsert(path: "diagnostics?on_conflict=id", body: [RemoteDiagnostic(diagnostic)])
        diagnostic.syncRequired = false
        try store.save()
    }

    func pushClient(_ client: ClientRecord) async throws {
        try await upsert(path: "clients?on_conflict=email", body: [RemoteClient(client)])
    }

    func pushFolder(_ folder: MailFolderRecord) async throws {
        try await upsert(path: "mail_folders?on_conflict=name", body: [RemoteFolder(folder)])
    }

    func pushMessage(_ message: MailMessageRecord) async throws {
        try await upsert(path: "mail_messages?on_conflict=id", body: [RemoteMail(message)])
        message.syncRequired = false
        try store.save()
    }

    func deleteMessage(id: String) async throws {
        var request = makeRequest(path: "mail_messages?id=eq.\(id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id)", method: "DELETE")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
    }

    private func get<Response: Decodable>(_ path: String) async throws -> Response {
        let request = makeRequest(path: path, method: "GET")
        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder.supabase.decode(Response.self, from: data)
    }

    private func upsert<Body: Encodable>(path: String, body: Body) async throws {
        guard network.isOnline else { throw APIError.offline }
        if useMocks { return }
        var request = makeRequest(path: path, method: "POST")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.myrtine.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        let url = URL(string: Self.baseURL.absoluteString + "/" + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue(MyrtineAPIClient.appToken, forHTTPHeaderField: "X-Myrtine-App-Token")
        return request
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "Réponse Supabase vide")
        }
    }
}

private struct RemoteDiagnostic: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let status: String
    let projectObject: String
    let projectOwner: String
    let sector: String
    let location: String
    let workforce: String
    let revenue: String
    let budget: String
    let schedule: String
    let expensesJSON: String
    let lastName: String
    let firstName: String
    let email: String
    let phone: String
    let resultMarkdown: String?
    let lastError: String?
    let isDeleted: Bool
    let syncRequired: Bool
    let isRead: Bool

    init(_ value: DiagnosticRecord) {
        id = value.id
        createdAt = value.createdAt
        updatedAt = value.updatedAt
        deletedAt = value.deletedAt
        status = value.stateRaw
        projectObject = value.projectObject
        projectOwner = value.projectOwner
        sector = value.sector
        location = value.location
        workforce = value.workforce
        revenue = value.revenue
        budget = value.budget
        schedule = value.schedule
        expensesJSON = String(data: (try? JSONEncoder().encode(value.expenses)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        lastName = value.lastName
        firstName = value.firstName
        email = value.email
        phone = value.phone
        resultMarkdown = value.resultMarkdown
        lastError = value.lastError
        isDeleted = value.isDeleted
        syncRequired = false
        isRead = value.isRead
    }

    var snapshot: DiagnosticSnapshot {
        DiagnosticSnapshot(id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, state: status, projectObject: projectObject, projectOwner: projectOwner, sector: sector, location: location, workforce: workforce, revenue: revenue, budget: budget, schedule: schedule, expenses: (try? JSONDecoder().decode([String].self, from: Data(expensesJSON.utf8))) ?? [], lastName: lastName, firstName: firstName, email: email, phone: phone, resultMarkdown: resultMarkdown ?? "", lastError: lastError ?? "", isDeleted: isDeleted, isRead: isRead)
    }

    enum CodingKeys: String, CodingKey {
        case id, status, sector = "secteur", location = "localisation", workforce = "effectif", schedule = "calendrier", email
        case createdAt = "created_at", updatedAt = "updated_at", deletedAt = "deleted_at"
        case projectObject = "objet_projet", projectOwner = "porteur_projet", revenue = "chiffre_affaires", budget = "budget_previsionnel"
        case expensesJSON = "depenses_json", lastName = "nom", firstName = "prenom", phone = "telephone"
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

    init(_ value: MailFolderRecord) {
        name = value.name; kind = value.isDeleted ? "deleted" : value.kind; sortOrder = value.sortOrder; createdAt = value.createdAt; updatedAt = value.updatedAt
    }
    enum CodingKeys: String, CodingKey { case name, kind; case sortOrder = "sort_order", createdAt = "created_at", updatedAt = "updated_at" }
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

    init(_ value: MailMessageRecord) {
        id = value.id; folderName = value.folderName; createdAt = value.createdAt; updatedAt = value.updatedAt; direction = value.direction; sender = value.sender; recipient = value.recipient; subject = value.subject; body = value.body; htmlBody = value.htmlBody; isRead = value.isRead
    }
    var snapshot: MailSnapshot { MailSnapshot(id: id, folderName: folderName, createdAt: createdAt, updatedAt: updatedAt, direction: direction, sender: sender, recipient: recipient, subject: subject, body: body, htmlBody: htmlBody ?? "", isRead: isRead) }
    enum CodingKeys: String, CodingKey {
        case id, direction, sender, recipient, subject, body
        case folderName = "folder_name", createdAt = "created_at", updatedAt = "updated_at", htmlBody = "html_body", isRead = "is_read"
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
