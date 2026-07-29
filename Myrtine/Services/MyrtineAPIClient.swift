import Foundation

@MainActor
final class MyrtineAPIClient {
    static let serverURL = URL(string: "https://serveur.myrtine.fr")!
    static let senderAddress = "contact@myrtine.fr"
    static let activationTokenAccount = "iphone-activation-token"
    private static let installationIDKey = "myrtine-installation-id"

    enum SimulationFailure: String, CaseIterable, Identifiable {
        case none = "Aucune"
        case perplexity = "Erreur Perplexity"
        case server = "Erreur serveur"
        case email = "Erreur e-mail"
        var id: String { rawValue }
    }

    struct DiagnosticResult: Sendable {
        let markdown: String
        let provider: String
        let model: String
        let primaryError: String?
    }

    private let network: NetworkMonitor
    private let store: LocalStore
    private let session: URLSession
    private let useMocks: Bool
    var simulatedFailure: SimulationFailure = .none

    var isActivated: Bool {
        useMocks || !(KeychainStore.get(Self.activationTokenAccount) ?? "").isEmpty
    }

    var installationID: String {
        if let existing = UserDefaults.standard.string(forKey: Self.installationIDKey), !existing.isEmpty { return existing }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: Self.installationIDKey)
        return created
    }

    init(network: NetworkMonitor, store: LocalStore, useMocks: Bool) {
        self.network = network
        self.store = store
        self.useMocks = useMocks
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 285
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func generateDiagnostic(for diagnostic: DiagnosticRecord) async throws -> DiagnosticResult {
        guard network.isOnline else { throw APIError.offline }
        if useMocks {
            try await Task.sleep(for: .milliseconds(650))
            if simulatedFailure == .perplexity || simulatedFailure == .server { throw APIError.simulated }
            return DiagnosticResult(markdown: SampleData.diagnosticMarkdown, provider: "Simulation", model: "sonar-pro-mock", primaryError: nil)
        }

        if simulatedFailure == .server { throw APIError.simulated }
        return try await generateThroughServer(diagnostic)
    }

    func activate(code: String, deviceName: String) async throws {
        guard network.isOnline else { throw APIError.offline }
        if useMocks {
            guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.server("Le code est requis.") }
            try KeychainStore.set("mock-device-token", for: Self.activationTokenAccount)
            return
        }
        let payload = ActivationPayload(action: "activate_device", code: code, installationID: installationID, deviceName: deviceName)
        let response: ActivationResponse = try await postServer(payload, requiresActivation: false)
        guard response.state == "appareil_active", !response.token.isEmpty else { throw APIError.server(response.message ?? response.state) }
        try KeychainStore.set(response.token, for: Self.activationTokenAccount)
    }

    func sendEmail(messageID: String, to email: String, subject: String, plainText: String, html: String, attachments: [MailAttachmentPayload]) async throws {
        guard network.isOnline else { throw APIError.offline }
        if useMocks {
            try await Task.sleep(for: .milliseconds(450))
            if simulatedFailure == .email { throw APIError.simulated }
            store.log(category: "E-mail", message: "E-mail simulé envoyé à \(email)")
            return
        }

        let payload = EmailPayload(action: "envoyer_email", messageID: messageID, email: email, subject: subject, message: plainText, htmlMessage: html, attachments: attachments)
        let response: ServerResponse = try await postServer(payload)
        guard response.state == "email_envoye" || response.state == "recue" else {
            throw APIError.server(response.message ?? response.state)
        }
    }

    func sendDiagnosticResult(_ diagnostic: DiagnosticRecord) async throws {
        guard network.isOnline else { throw APIError.offline }
        let payload = ResultEmailPayload(action: "envoyer_client", diagnosticID: diagnostic.id, lastName: diagnostic.lastName, firstName: diagnostic.firstName, email: diagnostic.email, result: diagnostic.resultMarkdown)
        let response: ServerResponse = try await postServer(payload)
        guard response.state == "email_envoye" || response.state == "recue" else {
            throw APIError.server(response.message ?? response.state)
        }
    }

    func synchronizeInbox() async throws -> Int {
        guard network.isOnline else { throw APIError.offline }
        if useMocks { return 1 }
        let response: ServerResponse = try await postServer(ActionPayload(action: "sync_inbox"))
        guard response.state == "mail_sync" || response.state == "imap_non_configure" else {
            throw APIError.server(response.message ?? response.state)
        }
        return response.count ?? 0
    }

    func registerPushToken(_ token: String, environment: String) async throws {
        guard network.isOnline else { throw APIError.offline }
        if useMocks { return }
        let response: ServerResponse = try await postServer(PushTokenPayload(action: "register_push", token: token, environment: environment))
        guard response.state == "push_enregistre" else { throw APIError.server(response.message ?? response.state) }
    }

    private func generateThroughServer(_ diagnostic: DiagnosticRecord) async throws -> DiagnosticResult {
        let payload = DiagnosticPayload(diagnostic)
        let response: ServerResponse = try await postServer(payload)
        guard response.state == "recue", let markdown = response.result, !markdown.isEmpty else {
            throw APIError.server(response.message ?? response.state)
        }
        return DiagnosticResult(markdown: markdown, provider: response.aiProvider ?? "Serveur Myrtine", model: response.aiModel ?? "", primaryError: response.primaryProviderError)
    }

    func postServer<Body: Encodable, Response: Decodable>(_ body: Body, requiresActivation: Bool = true) async throws -> Response {
        var request = URLRequest(url: Self.serverURL.appending(path: "diagnostic-flash"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iphone-app", forHTTPHeaderField: "X-Myrtine-Source")
        if requiresActivation {
            guard let token = KeychainStore.get(Self.activationTokenAccount), !token.isEmpty else { throw APIError.activationRequired }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.myrtine.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.myrtine.decode(Response.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder.myrtine.decode(ServerResponse.self, from: data).message) ?? String(data: data, encoding: .utf8) ?? "Réponse vide"
            throw APIError.http(http.statusCode, detail)
        }
    }
}

struct MailAttachmentPayload: Codable, Identifiable, Sendable {
    var id: String { "\(fileName)-\(contentID ?? "attachment")" }
    let fileName: String
    let contentType: String
    let base64Content: String
    let isInline: Bool
    let contentID: String?

    enum CodingKeys: String, CodingKey {
        case fileName, contentType, base64Content, isInline, contentID
    }
}

private struct DiagnosticPayload: Encodable {
    let action: String? = nil
    let diagnosticID: String
    let projectObject: String
    let projectOwner: String
    let sector: String
    let location: String
    let workforce: String
    let revenue: String
    let budget: String
    let schedule: String
    let expenses: [String]
    let lastName: String
    let firstName: String
    let email: String
    let phone: String

    init(_ value: DiagnosticRecord) {
        diagnosticID = value.id
        projectObject = value.projectObject
        projectOwner = value.projectOwner
        sector = value.sector
        location = value.location
        workforce = value.workforce
        revenue = value.revenue
        budget = value.budget
        schedule = value.schedule
        expenses = value.expenses
        lastName = value.lastName
        firstName = value.firstName
        email = value.email
        phone = value.phone
    }

    enum CodingKeys: String, CodingKey {
        case action
        case diagnosticID = "diagnostic_id"
        case projectObject = "objet_projet"
        case projectOwner = "porteur_projet"
        case sector = "secteur"
        case location = "localisation"
        case workforce = "effectif"
        case revenue = "chiffre_affaires"
        case budget = "budget_previsionnel"
        case schedule = "calendrier"
        case expenses = "depenses_concernees"
        case lastName = "nom"
        case firstName = "prenom"
        case email
        case phone = "telephone"
    }
}

private struct EmailPayload: Encodable {
    let action: String
    let messageID: String
    let email: String
    let subject: String
    let message: String
    let htmlMessage: String
    let attachments: [MailAttachmentPayload]
    enum CodingKeys: String, CodingKey {
        case action, email, attachments
        case messageID = "message_id"
        case subject = "sujet"
        case message
        case htmlMessage = "html_message"
    }
}

private struct ResultEmailPayload: Encodable {
    let action: String
    let diagnosticID: String
    let lastName: String
    let firstName: String
    let email: String
    let result: String
    enum CodingKeys: String, CodingKey {
        case action, email
        case diagnosticID = "diagnostic_id"
        case lastName = "nom"
        case firstName = "prenom"
        case result = "resultat"
    }
}

private struct ActionPayload: Encodable { let action: String }

private struct PushTokenPayload: Encodable {
    let action: String
    let token: String
    let environment: String
    enum CodingKeys: String, CodingKey {
        case action
        case token = "apns_token"
        case environment = "apns_environment"
    }
}

private struct ActivationPayload: Encodable {
    let action: String
    let code: String
    let installationID: String
    let deviceName: String
    enum CodingKeys: String, CodingKey {
        case action, code
        case installationID = "installation_id"
        case deviceName = "device_name"
    }
}

private struct ActivationResponse: Decodable {
    let state: String
    let token: String
    let message: String?
    enum CodingKeys: String, CodingKey { case state = "etat_de_la_requete", token, message }
}

private struct ServerResponse: Decodable {
    let state: String
    let message: String?
    let result: String?
    let diagnosticID: String?
    let aiProvider: String?
    let aiModel: String?
    let primaryProviderError: String?
    let count: Int?
    enum CodingKeys: String, CodingKey {
        case state = "etat_de_la_requete"
        case message
        case result = "resultat"
        case diagnosticID = "diagnostic_id"
        case aiProvider = "fournisseur_ia"
        case aiModel = "modele_ia"
        case primaryProviderError = "erreur_fournisseur_primaire"
        case count
    }
}

enum APIError: LocalizedError {
    case offline
    case activationRequired
    case simulated
    case invalidResponse
    case http(Int, String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .offline: "Vous êtes hors ligne. L'action a été conservée et reprendra dès que la connexion reviendra."
        case .activationRequired: "Cette installation doit être activée avant d'utiliser les services Myrtine."
        case .simulated: "Erreur simulée pour vérifier le comportement de l'application."
        case .invalidResponse: "La réponse du service est invalide."
        case let .http(code, detail): "Le service a répondu HTTP \(code) : \(detail)"
        case let .server(message): message
        }
    }
}

enum PromptBuilder {
    static let systemPrompt = """
    Tu es un expert senior des financements publics en France. Réponds exclusivement en français et en Markdown valide. Effectue une recherche web approfondie et actuelle. Vérifie chaque information sur une source officielle, avec aides-entreprises.fr uniquement comme source complémentaire. N'invente aucun dispositif, montant, délai, critère, lien ou contact.

    Recherche notamment les dispositifs de l'Union européenne (FEDER, FEADER, FSE+, Horizon Europe, LIFE, InvestEU, Erasmus+), de l'État, de la DGE et des ministères, de Bpifrance, de l'ADEME, de FranceAgriMer, des agences de l'eau, des régions, départements, métropoles, intercommunalités, chambres consulaires et crédits d'impôt. Vérifie que chaque dispositif est ouvert ou au fil de l'eau à la date de la demande et qu'il s'agit de sa version la plus récente.

    Présente d'abord un court résumé, puis un unique grand tableau Markdown. Une ligne correspond à une aide réellement pertinente. Colonnes exactes : Organisme financeur | Nom du dispositif | Subvention mobilisable | Critères à respecter | Échéance | Lien officiel | Cahier des charges en vigueur. Utilise des liens Markdown directs. Laisse la cellule du cahier des charges vide s'il n'existe pas. Développe les critères et les montants sans rendre les cellules illisibles. Après le tableau, ajoute les démarches prioritaires, les pièces à préparer et les risques d'inéligibilité.
    """

    static func userPrompt(for d: DiagnosticRecord) -> String {
        """
        Date de référence : \(Date.now.formatted(date: .complete, time: .omitted)), heure de Paris.

        Demandeur : \(d.firstName) \(d.lastName), \(d.email), \(d.phone.isEmpty ? "téléphone non renseigné" : d.phone).
        Objet du projet : \(d.projectObject)
        Porteur du projet : \(d.projectOwner)
        Secteur : \(d.sector)
        Localisation : \(d.location)
        Effectif : \(d.workforce)
        Chiffre d'affaires : \(d.revenue.isEmpty ? "non renseigné" : d.revenue)
        Budget prévisionnel : \(d.budget)
        Calendrier : \(d.schedule)
        Dépenses : \(d.expenses.joined(separator: ", "))

        Identifie toutes les aides auxquelles ce projet semble réellement éligible. Pour chaque ligne, vérifie l'URL directe du dispositif, son règlement ou cahier des charges actuel lorsqu'il existe, le montant mobilisable et l'échéance. Si une information n'est pas vérifiable, indique « Information non vérifiée » au lieu de l'inventer.
        """
    }
}

extension JSONEncoder {
    static var myrtine: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var myrtine: JSONDecoder {
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
