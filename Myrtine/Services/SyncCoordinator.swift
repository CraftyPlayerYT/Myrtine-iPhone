import Foundation

@MainActor
final class SyncCoordinator {
    private let network: NetworkMonitor
    private let store: LocalStore
    private let api: MyrtineAPIClient
    private let supabase: SupabaseSyncClient

    init(network: NetworkMonitor, store: LocalStore, api: MyrtineAPIClient, supabase: SupabaseSyncClient) {
        self.network = network
        self.store = store
        self.api = api
        self.supabase = supabase
    }

    func synchronize() async throws {
        guard network.isOnline else { return }
        do {
            let count = try await api.synchronizeInbox()
            if count > 0 { store.log(category: "E-mail", message: "\(count) nouveau(x) message(s) récupéré(s)") }
        } catch {
            store.log(level: "Avertissement", category: "E-mail", message: "La relève IMAP n'a pas abouti", detail: error.localizedDescription)
        }

        try await supabase.pullAll()
        for operation in store.pendingOperations() {
            do {
                try await process(operation)
                try store.complete(operation)
            } catch {
                operation.attempts += 1
                operation.lastError = error.localizedDescription
                try? store.save()
                store.log(level: "Avertissement", category: "File d'attente", message: "Opération \(operation.operation) conservée", detail: error.localizedDescription)
            }
        }
        try await supabase.pullAll()
    }

    func submit(_ diagnostic: DiagnosticRecord) async throws {
        if !network.isOnline {
            diagnostic.state = .queued
            diagnostic.syncRequired = true
            diagnostic.updatedAt = .now
            try store.enqueue(operation: "send_diagnostic", entityID: diagnostic.id)
            return
        }
        try await performDiagnostic(diagnostic)
    }

    func send(message: MailMessageRecord, attachments: [MailAttachmentPayload]) async throws {
        message.attachmentsData = (try? JSONEncoder().encode(attachments)) ?? Data()
        try store.saveMessage(message)
        if !network.isOnline {
            try store.enqueue(operation: "send_email", entityID: message.id)
            return
        }
        try await performEmail(message, attachments: attachments)
    }

    private func process(_ operation: PendingOperationRecord) async throws {
        switch operation.operation {
        case "send_diagnostic":
            guard let diagnostic = store.diagnostic(id: operation.entityID) else { return }
            try await performDiagnostic(diagnostic)
        case "send_email":
            guard let message = store.message(id: operation.entityID) else { return }
            let attachments = (try? JSONDecoder().decode([MailAttachmentPayload].self, from: message.attachmentsData)) ?? []
            try await performEmail(message, attachments: attachments)
        case "upsert_diagnostic":
            guard let diagnostic = store.diagnostic(id: operation.entityID) else { return }
            try await supabase.pushDiagnostic(diagnostic)
        case "upsert_message":
            guard let message = store.message(id: operation.entityID) else { return }
            try await supabase.pushMessage(message)
        case "upsert_folder", "rename_folder":
            guard let folder = store.folders(includeDeleted: true).first(where: { $0.id == operation.entityID }) else { return }
            try await supabase.pushFolder(folder)
        case "delete_message":
            try await supabase.deleteMessage(id: operation.entityID)
        default:
            store.log(level: "Avertissement", category: "File d'attente", message: "Opération inconnue ignorée", detail: operation.operation)
        }
    }

    private func performDiagnostic(_ diagnostic: DiagnosticRecord) async throws {
        diagnostic.state = .sending
        diagnostic.lastError = ""
        diagnostic.updatedAt = .now
        try store.save()
        do {
            let result = try await api.generateDiagnostic(for: diagnostic)
            diagnostic.resultMarkdown = result.markdown
            diagnostic.aiProvider = result.provider
            diagnostic.aiModel = result.model
            diagnostic.state = .received
            diagnostic.isRead = false
            diagnostic.syncRequired = true
            diagnostic.updatedAt = .now
            try store.upsertClient(from: diagnostic)
            try store.save()
            try await supabase.pushDiagnostic(diagnostic)
            if let primaryError = result.primaryError, !primaryError.isEmpty {
                store.log(level: "Avertissement", category: "IA", message: "Le fournisseur de repli a été utilisé", detail: primaryError)
            }
        } catch {
            diagnostic.state = network.isOnline ? .failed : .queued
            diagnostic.lastError = error.localizedDescription
            diagnostic.updatedAt = .now
            diagnostic.syncRequired = true
            try store.save()
            throw error
        }
    }

    private func performEmail(_ message: MailMessageRecord, attachments: [MailAttachmentPayload]) async throws {
        try await api.sendEmail(to: message.recipient, subject: message.subject, plainText: message.body, html: message.htmlBody, attachments: attachments)
        message.folderName = "Éléments envoyés"
        message.isRead = true
        message.syncRequired = true
        message.updatedAt = .now
        try store.save()
        try await supabase.pushMessage(message)
    }
}
