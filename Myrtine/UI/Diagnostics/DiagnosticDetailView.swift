import SwiftUI

struct DiagnosticDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let diagnostic: DiagnosticRecord
    @State private var showSendConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    identity
                    project
                    if !diagnostic.resultMarkdown.isEmpty {
                        Surface {
                            Text("Résultat").font(.title2.weight(.bold))
                            MarkdownDocumentView(markdown: diagnostic.resultMarkdown)
                        }
                    } else if !diagnostic.lastError.isEmpty {
                        Surface {
                            Label("Le diagnostic n'a pas abouti", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(.red)
                            Text(diagnostic.lastError).font(.subheadline).textSelection(.enabled)
                        }
                    }
                }
                .padding(16)
            }
            .myrtineScreen()
            .navigationTitle("Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.frame(minHeight: 44) }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !diagnostic.resultMarkdown.isEmpty {
                            Button { sendResult() } label: { Label("Envoyer par e-mail", systemImage: "paperplane") }
                        }
                        Button(role: .destructive) { try? environment.store.moveDiagnosticToTrash(diagnostic); dismiss() } label: { Label("Mettre à la corbeille", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityIdentifier("diagnostic-actions")
                }
            }
            .task {
                if !diagnostic.isRead { try? environment.store.markDiagnosticRead(diagnostic) }
            }
        }
    }

    private var identity: some View {
        Surface {
            HStack(alignment: .top, spacing: 14) {
                Circle().fill(MyrtineTheme.accent.opacity(0.12)).frame(width: 56, height: 56)
                    .overlay { Text(String(diagnostic.firstName.prefix(1)) + String(diagnostic.lastName.prefix(1))).font(.headline).foregroundStyle(MyrtineTheme.accent) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(diagnostic.fullName).font(.title3.weight(.bold))
                    Link(diagnostic.email, destination: URL(string: "mailto:\(diagnostic.email)")!)
                    if !diagnostic.phone.isEmpty { Link(diagnostic.phone, destination: URL(string: "tel:\(diagnostic.phone.filter(\.isNumber))")!) }
                }
                Spacer()
            }
        }
    }

    private var project: some View {
        Surface {
            Text("Informations transmises").font(.title3.weight(.bold))
            DetailLine(label: "Projet", value: diagnostic.projectObject)
            DetailLine(label: "Porteur", value: diagnostic.projectOwner)
            DetailLine(label: "Secteur", value: diagnostic.sector)
            DetailLine(label: "Localisation", value: diagnostic.location)
            DetailLine(label: "Effectif", value: diagnostic.workforce)
            DetailLine(label: "Chiffre d'affaires", value: diagnostic.revenue)
            DetailLine(label: "Budget", value: diagnostic.budget)
            DetailLine(label: "Calendrier", value: diagnostic.schedule)
            DetailLine(label: "Dépenses", value: diagnostic.expenses.joined(separator: "\n"))
        }
    }

    private func sendResult() {
        Task {
            do {
                try await environment.api.sendDiagnosticResult(diagnostic)
                environment.toast = ToastMessage(title: "Résultat envoyé", message: "Le client le recevra par e-mail.", kind: .success)
            } catch {
                environment.toast = ToastMessage(title: "Envoi impossible", message: error.localizedDescription, kind: .error)
            }
        }
    }
}

private struct DetailLine: View {
    let label: String
    let value: String
    var body: some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.body).textSelection(.enabled)
            }
            .padding(.top, 8)
        }
    }
}
