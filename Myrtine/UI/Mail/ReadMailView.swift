import SwiftUI
import WebKit

struct ReadMailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let message: MailMessageRecord
    @State private var composeMode: ComposeMode?
    @State private var htmlIsVisible = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                ZStack(alignment: .topLeading) {
                    if !htmlIsVisible {
                        ScrollView([.horizontal, .vertical]) {
                            Text(message.body.isEmpty ? "Ce message ne contient aucun texte." : message.body)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .accessibilityIdentifier("mail-reader-fallback")
                    }
                    MailHTMLView(html: message.htmlBody, fallback: message.body, isVisible: $htmlIsVisible)
                        .opacity(htmlIsVisible ? 1 : 0)
                }
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
}

private struct MailHTMLView: UIViewRepresentable {
    let html: String
    let fallback: String
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
        let source = html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? escapedFallback : html
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
        :root{color-scheme:light}*{box-sizing:border-box}html,body{margin:0;background:transparent;color:#171b2e;font:17px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}body{padding:18px;overflow-x:auto}table{border-collapse:collapse;min-width:max-content}th,td{border:1px solid #cbd5e1;padding:9px;vertical-align:top}img{height:auto;max-height:70vh}a{color:#3859c7;overflow-wrap:anywhere}pre{white-space:pre;overflow-x:auto}
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
