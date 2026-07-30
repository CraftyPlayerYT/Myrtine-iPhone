import SwiftUI
import WebKit

struct ReadMailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let message: MailMessageRecord
    @State private var composeMode: ComposeMode?
    @State private var htmlIsVisible = false

    private var attachments: [MailAttachmentPayload] {
        (try? JSONDecoder().decode([MailAttachmentPayload].self, from: message.attachmentsData)) ?? []
    }

    private var regularAttachments: [MailAttachmentPayload] { attachments.filter { !$0.isInline } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                if message.htmlBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    plainTextBody
                } else {
                    ZStack(alignment: .topLeading) {
                        if !htmlIsVisible { plainTextBody }
                        MailHTMLView(html: message.htmlBody, fallback: message.body, attachments: attachments, isVisible: $htmlIsVisible)
                            .opacity(htmlIsVisible ? 1 : 0)
                    }
                }
                if !regularAttachments.isEmpty { attachmentList }
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
                    if message.isTrashed {
                        Button { try? environment.store.restoreMessage(message); dismiss() } label: { Label("Restaurer", systemImage: "arrow.uturn.backward") }.buttonStyle(.bordered).frame(minHeight: 48)
                    } else {
                        Button(role: .destructive) { try? environment.store.moveMessage(message, to: "Corbeille"); dismiss() } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Supprimer")
                    }
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

    private var plainTextBody: some View {
        ScrollView {
            Text(message.body.isEmpty ? "Ce message ne contient aucun texte." : message.body)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .accessibilityIdentifier("mail-reader-body")
    }

    private var attachmentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            ForEach(regularAttachments) { attachment in
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill").foregroundStyle(MyrtineTheme.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.fileName).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
            }
        }
        .background(MyrtineTheme.canvas)
        .accessibilityIdentifier("mail-reader-attachments")
    }
}

private struct MailHTMLView: UIViewRepresentable {
    let html: String
    let fallback: String
    let attachments: [MailAttachmentPayload]
    @Binding var isVisible: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.alwaysBounceHorizontal = false
        view.accessibilityIdentifier = "rich-mail-reader"
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let rawSource = html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? escapedFallback : html
        let source = MailHTMLRenderer.prepare(rawSource, attachments: attachments)
        guard context.coordinator.loadedSource != source else { return }
        context.coordinator.loadedSource = source
        isVisible = false
        view.loadHTMLString(document(for: source), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(isVisible: $isVisible) }

    private var escapedFallback: String {
        fallback
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func document(for source: String) -> String {
        """
        <!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        :root{color-scheme:light}*{box-sizing:border-box}html,body{width:100%;margin:0;background:transparent;color:#171b2e;font:17px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}body{padding:18px;overflow-x:hidden;overflow-wrap:anywhere}table{display:block;max-width:100%;overflow-x:auto;border-collapse:collapse;-webkit-overflow-scrolling:touch}th,td{min-width:150px;border:1px solid #cbd5e1;padding:9px;vertical-align:top}img{display:block;max-width:100%;height:auto;max-height:70vh;object-fit:contain}a{color:#3859c7;overflow-wrap:anywhere}pre{max-width:100%;white-space:pre;overflow-x:auto}
        </style></head><body>\(source)</body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedSource = ""
        private let isVisible: Binding<Bool>

        init(isVisible: Binding<Bool>) {
            self.isVisible = isVisible
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isVisible.wrappedValue = true
            }
        }
    }
}

enum MailHTMLRenderer {
    static func prepare(_ html: String, attachments: [MailAttachmentPayload]) -> String {
        var result = bodyFragment(from: html)
        result = result.replacingOccurrences(of: "<script\\b[^>]*>[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
        for attachment in attachments where attachment.isInline {
            guard let cid = attachment.contentID, attachment.byteCount > 0 else { continue }
            let dataURL = "data:\(attachment.contentType);base64,\(attachment.base64Content)"
            result = result.replacingOccurrences(of: "cid:\(cid)", with: dataURL, options: .caseInsensitive)
        }
        return result
    }

    static func bodyFragment(from html: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: "<body\\b[^>]*>([\\s\\S]*?)</body>", options: .caseInsensitive),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return html
        }
        return String(html[range])
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
