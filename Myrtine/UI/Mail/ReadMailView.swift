import SwiftUI

struct ReadMailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let message: MailMessageRecord
    @State private var controller: RichTextEditorController
    @State private var composeMode: ComposeMode?

    init(message: MailMessageRecord) {
        self.message = message
        let reader = RichTextEditorController()
        reader.load(html: message.htmlBody, fallback: message.body)
        _controller = State(initialValue: reader)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                RichTextEditor(controller: controller, isEditable: false)
                    .background(Color.white)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(message.subject.isEmpty ? "(Sans objet)" : message.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.frame(minHeight: 44).accessibilityIdentifier("mail-reader-close") }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { composeMode = .reply } label: { Label("Répondre", systemImage: "arrowshape.turn.up.left") }
                        Button { composeMode = .forward } label: { Label("Transférer", systemImage: "arrowshape.turn.up.right") }
                        if message.isTrashed {
                            Button { try? environment.store.restoreMessage(message); dismiss() } label: { Label("Restaurer", systemImage: "arrow.uturn.backward") }
                        } else {
                            Button { try? environment.store.moveMessage(message, to: "Archives"); dismiss() } label: { Label("Archiver", systemImage: "archivebox") }
                            Button(role: .destructive) { try? environment.store.moveMessage(message, to: "Corbeille"); dismiss() } label: { Label("Supprimer", systemImage: "trash") }
                        }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Actions du message")
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { composeMode = .reply } label: { Label("Répondre", systemImage: "arrowshape.turn.up.left") }.buttonStyle(.borderedProminent).frame(minHeight: 48)
                    Button { composeMode = .forward } label: { Label("Transférer", systemImage: "arrowshape.turn.up.right") }.buttonStyle(.bordered).frame(minHeight: 48)
                    Spacer()
                    Button(role: .destructive) { try? environment.store.moveMessage(message, to: "Corbeille"); dismiss() } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Supprimer")
                }
                .padding(.horizontal, 16).padding(.vertical, 8).background(.ultraThinMaterial)
            }
            .fullScreenCover(item: $composeMode) { mode in
                ComposeMailView(recipient: mode == .reply ? message.sender : "", subject: mode.subject(for: message.subject), body: mode.body(for: message))
            }
            .task {
                if !message.isRead { message.isRead = true; message.updatedAt = .now; message.syncRequired = true; try? environment.store.enqueue(operation: "upsert_message", entityID: message.id) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(MyrtineTheme.leaf.opacity(0.15)).frame(width: 48, height: 48)
                .overlay { Text(String(message.correspondent.prefix(1)).uppercased()).font(.headline).foregroundStyle(MyrtineTheme.leaf) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.sender).font(.body.weight(.semibold)).textSelection(.enabled)
                Text("À : \(message.recipient)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

private enum ComposeMode: String, Identifiable {
    case reply, forward
    var id: String { rawValue }
    func subject(for subject: String) -> String {
        switch self {
        case .reply: subject.lowercased().hasPrefix("re:") ? subject : "Re: \(subject)"
        case .forward: subject.lowercased().hasPrefix("tr:") ? subject : "Tr: \(subject)"
        }
    }
    func body(for message: MailMessageRecord) -> String {
        switch self {
        case .reply: "\n\nLe \(message.createdAt.formatted(date: .abbreviated, time: .shortened)), \(message.sender) a écrit :\n\(message.body)"
        case .forward: "\n\n---------- Message transféré ----------\nDe : \(message.sender)\nÀ : \(message.recipient)\nObjet : \(message.subject)\n\n\(message.body)"
        }
    }
}
