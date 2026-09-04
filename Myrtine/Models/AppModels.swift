import Foundation
import SwiftData

enum DiagnosticState: String, Codable, CaseIterable, Sendable {
    case draft = "Brouillon"
    case queued = "À synchroniser"
    case sending = "Envoi en cours"
    case received = "Reçu"
    case sent = "Envoyé"
    case failed = "Erreur"
    case deleted = "Dans la corbeille"
}

@Model
final class DiagnosticRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var stateRaw: String
    var projectObject: String
    var projectOwner: String
    var sector: String
    var location: String
    var workforce: String
    var revenue: String
    var budget: String
    var schedule: String
    var expenses: [String]
    var additionalInformation: String = ""
    var lastName: String
    var firstName: String
    var email: String
    var phone: String
    var resultMarkdown: String
    var lastError: String
    var isTrashed: Bool
    var syncRequired: Bool
    var isRead: Bool
    var aiProvider: String
    var aiModel: String

    init(
        id: String = UUID().uuidString.lowercased(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        state: DiagnosticState = .draft,
        projectObject: String = "",
        projectOwner: String = "",
        sector: String = "",
        location: String = "",
        workforce: String = "",
        revenue: String = "",
        budget: String = "",
        schedule: String = "",
        expenses: [String] = [],
        additionalInformation: String = "",
        lastName: String = "",
        firstName: String = "",
        email: String = "",
        phone: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = nil
        self.stateRaw = state.rawValue
        self.projectObject = projectObject
        self.projectOwner = projectOwner
        self.sector = sector
        self.location = location
        self.workforce = workforce
        self.revenue = revenue
        self.budget = budget
        self.schedule = schedule
        self.expenses = expenses
        self.additionalInformation = additionalInformation
        self.lastName = lastName
        self.firstName = firstName
        self.email = email
        self.phone = phone
        self.resultMarkdown = ""
        self.lastError = ""
        self.isTrashed = false
        self.syncRequired = false
        self.isRead = false
        self.aiProvider = ""
        self.aiModel = ""
    }

    var state: DiagnosticState {
        get { DiagnosticState(rawValue: stateRaw) ?? .draft }
        set { stateRaw = newValue.rawValue }
    }

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var isComplete: Bool {
        !projectObject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !projectOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !workforce.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !budget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !expenses.isEmpty
    }
}

@Model
final class ClientRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var updatedAt: Date
    var lastName: String
    var firstName: String
    @Attribute(.unique) var email: String
    var phone: String
    var company: String
    var notes: String

    init(id: String = UUID().uuidString.lowercased(), createdAt: Date = .now, updatedAt: Date = .now, lastName: String, firstName: String, email: String, phone: String = "", company: String = "", notes: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastName = lastName
        self.firstName = firstName
        self.email = email.lowercased()
        self.phone = phone
        self.company = company
        self.notes = notes
    }

    var fullName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }
}

@Model
final class MailFolderRecord {
    @Attribute(.unique) var id: String
    @Attribute(.unique) var name: String
    var systemImage: String
    var kind: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var isTrashed: Bool
    var previousName: String

    init(id: String = UUID().uuidString.lowercased(), name: String, systemImage: String = "folder", kind: String = "custom", sortOrder: Int = 100, createdAt: Date = .now, updatedAt: Date = .now, isTrashed: Bool = false, previousName: String = "") {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.kind = kind
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTrashed = isTrashed
        self.previousName = previousName
    }
}

@Model
final class MailMessageRecord {
    @Attribute(.unique) var id: String
    var folderName: String
    var previousFolderName: String
    var createdAt: Date
    var updatedAt: Date
    var direction: String
    var sender: String
    var recipient: String
    var subject: String
    var body: String
    var htmlBody: String
    var attachmentsData: Data
    var isRead: Bool
    var isTrashed: Bool
    var syncRequired: Bool

    init(id: String = UUID().uuidString.lowercased(), folderName: String, previousFolderName: String = "", createdAt: Date = .now, updatedAt: Date = .now, direction: String, sender: String, recipient: String, subject: String, body: String, htmlBody: String = "", attachmentsData: Data = Data(), isRead: Bool = true, isTrashed: Bool = false, syncRequired: Bool = false) {
        self.id = id
        self.folderName = folderName
        self.previousFolderName = previousFolderName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.direction = direction
        self.sender = sender
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.htmlBody = htmlBody
        self.attachmentsData = attachmentsData
        self.isRead = isRead
        self.isTrashed = isTrashed
        self.syncRequired = syncRequired
    }

    var correspondent: String { direction == "sent" ? recipient : sender }
}

@Model
final class LogRecord {
    @Attribute(.unique) var id: String
    var date: Date
    var level: String
    var category: String
    var message: String
    var detail: String

    init(id: String = UUID().uuidString.lowercased(), date: Date = .now, level: String = "Information", category: String, message: String, detail: String = "") {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
        self.detail = detail
    }
}

@Model
final class PendingOperationRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var operation: String
    var entityID: String
    var attempts: Int
    var lastError: String

    init(id: String = UUID().uuidString.lowercased(), createdAt: Date = .now, operation: String, entityID: String, attempts: Int = 0, lastError: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.operation = operation
        self.entityID = entityID
        self.attempts = attempts
        self.lastError = lastError
    }
}

enum MyrtineSchema {
    static let types: [any PersistentModel.Type] = [
        DiagnosticRecord.self,
        ClientRecord.self,
        MailFolderRecord.self,
        MailMessageRecord.self,
        LogRecord.self,
        PendingOperationRecord.self
    ]
}
