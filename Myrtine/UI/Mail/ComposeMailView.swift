import SwiftUI
import UniformTypeIdentifiers

struct ComposeMailView: View {
    private static let maxAttachmentBytes = 3 * 1024 * 1024
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let existingDraft: MailMessageRecord?
    let initialRecipient: String
    let initialSubject: String
    let initialBody: String

    @State private var recipient: String
    @State private var subject: String
    @State private var controller: RichTextEditorController
    @State private var isSending = false
    @State private var showImageImporter = false
    @State private var showDocumentImporter = false
    @State private var showTextColor = false
    @State private var showHighlightColor = false
    @State private var showLinkPrompt = false
    @State private var linkValue = "https://"
    @State private var errorMessage: String?

    init(existingDraft: MailMessageRecord? = nil, recipient: String = "", subject: String = "", body: String = "") {
        self.existingDraft = existingDraft
        initialRecipient = recipient
        initialSubject = subject
        initialBody = body
        _recipient = State(initialValue: existingDraft?.recipient ?? recipient)
        _subject = State(initialValue: existingDraft?.subject ?? subject)
        let editor = RichTextEditorController()
        if let draft = existingDraft {
            editor.load(html: draft.htmlBody, fallback: draft.body)
            let restored = (try? JSONDecoder().decode([MailAttachmentPayload].self, from: draft.attachmentsData)) ?? []
            editor.inlineAttachments = restored.filter(\.isInline)
            editor.regularAttachments = restored.filter { !$0.isInline }
        }
        else { editor.attributedText = NSAttributedString(string: body, attributes: RichTextEditorController.defaultAttributes) }
        _controller = State(initialValue: editor)
    }

    private var canSend: Bool {
        recipient.contains("@") && !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !controller.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addressing
                formattingBar
                Divider()
                RichTextEditor(controller: controller)
                    .background(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                attachments
            }
            .background(Color.white)
            .navigationTitle("Nouveau message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }.frame(minHeight: 44).disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { send() } label: {
                        if isSending { ProgressView() } else { Label("Envoyer", systemImage: "paperplane.fill") }
                    }
                    .disabled(!canSend || isSending)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("compose-send")
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .alert("Ajouter un lien", isPresented: $showLinkPrompt) {
                TextField("https://…", text: $linkValue)
                    .textInputAutocapitalization(.never)
                Button("Annuler", role: .cancel) { }
                Button("Ajouter") {
                    do { try controller.insertLink(linkValue) } catch { errorMessage = error.localizedDescription }
                }
            } message: { Text("Le lien sera appliqué au texte sélectionné.") }
            .alert("Impossible d'effectuer l'action", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Erreur inconnue") }
            .fullScreenCover(isPresented: $showTextColor) {
                ColorSelectionView(title: "Couleur du texte", initialColor: controller.textColor) { controller.applyTextColor($0) }
            }
            .fullScreenCover(isPresented: $showHighlightColor) {
                ColorSelectionView(title: "Surlignage", initialColor: controller.highlightColor, allowsClear: true, onSelect: { controller.applyHighlight($0) }, onClear: { controller.clearHighlight() })
            }
            .fileImporter(isPresented: $showImageImporter, allowedContentTypes: imageTypes, allowsMultipleSelection: false) { result in importImage(result) }
            .fileImporter(isPresented: $showDocumentImporter, allowedContentTypes: [.data, .pdf, .plainText, .zip], allowsMultipleSelection: true) { result in importDocuments(result) }
            .interactiveDismissDisabled(isSending)
        }
    }

    private var addressing: some View {
        VStack(spacing: 0) {
            HStack {
                Text("À").foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
                TextField("nom@entreprise.fr", text: $recipient)
                    .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("compose-recipient")
            }
            .frame(minHeight: 50).padding(.horizontal, 16)
            Divider().padding(.leading, 62)
            HStack {
                Text("Objet").foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
                TextField("Objet du message", text: $subject).accessibilityIdentifier("compose-subject")
            }
            .frame(minHeight: 50).padding(.horizontal, 16)
            Divider()
        }
        .font(.body)
        .background(Color.white)
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FormatButton(systemImage: "bold", active: controller.isBold, label: "Gras") { controller.toggleBold() }
                FormatButton(systemImage: "italic", active: controller.isItalic, label: "Italique") { controller.toggleItalic() }
                FormatButton(systemImage: "underline", active: controller.isUnderlined, label: "Souligné") { controller.toggleUnderline() }
                Menu {
                    ForEach([13, 15, 17, 20, 24, 30], id: \.self) { size in Button("\(size) pt") { controller.applyFontSize(CGFloat(size)) } }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                        Text("\(Int(controller.fontSize))").font(.caption.weight(.semibold))
                    }
                    .frame(minWidth: 58, minHeight: 46)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .accessibilityLabel("Taille du texte")
                FormatButton(systemImage: "paintbrush.fill", active: false, label: "Couleur du texte", swatch: Color(uiColor: controller.textColor)) { showTextColor = true }
                FormatButton(systemImage: "highlighter", active: false, label: "Surlignage", swatch: Color(uiColor: controller.highlightColor)) { showHighlightColor = true }
                FormatButton(systemImage: "link", active: false, label: "Insérer un lien") { showLinkPrompt = true }
                FormatButton(systemImage: "photo", active: false, label: "Insérer une image") { showImageImporter = true }
                FormatButton(systemImage: "paperclip", active: false, label: "Joindre un document") { showDocumentImporter = true }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(MyrtineTheme.canvas)
        .accessibilityIdentifier("compose-formatting")
    }

    @ViewBuilder private var attachments: some View {
        if !controller.regularAttachments.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                ForEach(controller.regularAttachments) { attachment in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill").foregroundStyle(MyrtineTheme.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.fileName).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { controller.removeAttachment(attachment) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Retirer \(attachment.fileName)")
                    }
                    .padding(.leading, 14).padding(.trailing, 6)
                    .frame(minHeight: 52)
                }
            }
            .background(MyrtineTheme.canvas)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { saveDraft() } label: { Label("Enregistrer", systemImage: "tray.and.arrow.down") }
                .buttonStyle(.bordered)
                .frame(minHeight: 46)
                .accessibilityIdentifier("compose-save-draft")
            Spacer()
            Button(role: .destructive) { deleteDraft() } label: { Label("Supprimer", systemImage: "trash") }
                .buttonStyle(.bordered)
                .frame(minHeight: 46)
                .accessibilityIdentifier("compose-delete-draft")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var imageTypes: [UTType] {
        [UTType.png, UTType.jpeg, UTType(filenameExtension: "svg"), UTType(filenameExtension: "webp")].compactMap { $0 }
    }

    private func message(folder: String) -> MailMessageRecord {
        let value = existingDraft ?? MailMessageRecord(folderName: folder, direction: "sent", sender: MyrtineAPIClient.senderAddress, recipient: recipient, subject: subject, body: controller.plainText, htmlBody: controller.htmlDocument())
        value.folderName = folder
        value.recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        value.subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        value.body = controller.plainText
        value.htmlBody = controller.htmlDocument()
        value.attachmentsData = (try? JSONEncoder().encode(controller.inlineAttachments + controller.regularAttachments)) ?? Data()
        value.updatedAt = .now
        return value
    }

    private func saveDraft() {
        do {
            try environment.store.saveMessage(message(folder: "Brouillons"))
            environment.toast = ToastMessage(title: "Brouillon enregistré", message: "Le message reste modifiable.", kind: .success)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteDraft() {
        if let existingDraft { try? environment.store.moveMessage(existingDraft, to: "Corbeille") }
        environment.toast = ToastMessage(title: "Brouillon supprimé", message: "Il se trouve dans la corbeille.", kind: .information)
        dismiss()
    }

    private func send() {
        isSending = true
        let outgoing = message(folder: "Brouillons")
        Task {
            do {
                try await environment.sync.send(message: outgoing, attachments: controller.inlineAttachments + controller.regularAttachments)
                environment.toast = ToastMessage(title: environment.network.isOnline ? "Message envoyé" : "Message mis en attente", message: outgoing.recipient, kind: .success)
                isSending = false
                dismiss()
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importImage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            try validateCapacity(adding: data.count)
            try controller.insertImage(data: data, fileName: url.lastPathComponent, contentType: type)
        } catch { errorMessage = error.localizedDescription }
    }

    private func importDocuments(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                try validateCapacity(adding: data.count)
                if type.lowercased().hasPrefix("image/") {
                    try controller.insertImage(data: data, fileName: url.lastPathComponent, contentType: type)
                } else {
                    controller.addDocument(data: data, fileName: url.lastPathComponent, contentType: type)
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func validateCapacity(adding bytes: Int) throws {
        let current = (controller.inlineAttachments + controller.regularAttachments).reduce(0) { $0 + $1.byteCount }
        guard bytes > 0 else { throw ImportError.empty }
        guard current + bytes <= Self.maxAttachmentBytes else { throw ImportError.tooLarge }
    }

    enum ImportError: LocalizedError {
        case empty, tooLarge
        var errorDescription: String? {
            switch self {
            case .empty: "Le fichier sélectionné est vide."
            case .tooLarge: "La taille totale des pièces jointes ne peut pas dépasser 3 Mo."
            }
        }
    }
}

private struct FormatButton: View {
    let systemImage: String
    let active: Bool
    let label: String
    var swatch: Color? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(active ? Color.white : MyrtineTheme.ink)
                    .frame(width: 46, height: 46)
                if let swatch {
                    Circle()
                        .fill(swatch)
                        .frame(width: 13, height: 13)
                        .overlay { Circle().stroke(.white, lineWidth: 2) }
                        .offset(x: 1, y: 1)
                }
            }
            .glassEffect(active ? .regular.tint(MyrtineTheme.accent).interactive() : .regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
            .accessibilityLabel(label)
            .accessibilityAddTraits(active ? .isSelected : [])
    }
}
