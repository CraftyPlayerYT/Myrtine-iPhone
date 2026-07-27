import SwiftUI
import SwiftData

struct DiagnosticsHomeView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case unread = "Nouveaux"
        case read = "Lus"
        case trash = "Corbeille"
        var id: String { rawValue }
    }

    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \DiagnosticRecord.updatedAt, order: .reverse) private var allDiagnostics: [DiagnosticRecord]
    @State private var scope: Scope = .unread
    @State private var search = ""
    @State private var selectedDiagnostic: DiagnosticRecord?
    @State private var showDetails = false
    @State private var showNewDiagnostic = false

    private var filtered: [DiagnosticRecord] {
        allDiagnostics.filter { diagnostic in
            let inScope = switch scope {
            case .unread: !diagnostic.isDeleted && !diagnostic.isRead
            case .read: !diagnostic.isDeleted && diagnostic.isRead
            case .trash: diagnostic.isDeleted
            }
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return inScope && (query.isEmpty || [diagnostic.fullName, diagnostic.email, diagnostic.projectObject, diagnostic.sector, diagnostic.location].contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("État", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .accessibilityIdentifier("diagnostic-scope")

                if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: scope == .trash ? "trash" : "doc.text.magnifyingglass",
                        title: scope == .unread ? "Aucun nouveau diagnostic" : "Aucun diagnostic",
                        message: scope == .unread ? "Les demandes du site apparaîtront ici après synchronisation." : "Cette section est vide."
                    )
                } else {
                    List(filtered) { diagnostic in
                        HStack(spacing: 4) {
                            Button { open(diagnostic) } label: { DiagnosticListRow(diagnostic: diagnostic) }
                                .buttonStyle(.plain)
                            Menu { actions(for: diagnostic) } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Actions pour \(diagnostic.fullName)")
                        }
                        .listRowBackground(Color.white)
                        .contextMenu { actions(for: diagnostic) }
                        .accessibilityIdentifier("diagnostic-row-\(diagnostic.id)")
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await environment.synchronize() }
                }
            }
            .myrtineScreen()
            .navigationTitle("Diagnostics")
            .searchable(text: $search, prompt: "Nom, e-mail, secteur…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if environment.isSyncing { ProgressView().accessibilityLabel("Synchronisation") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewDiagnostic = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Nouveau diagnostic")
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("diagnostics-new")
                }
            }
            .fullScreenCover(isPresented: $showNewDiagnostic) { NewDiagnosticView() }
            .fullScreenCover(isPresented: $showDetails, onDismiss: { selectedDiagnostic = nil }) {
                if let selectedDiagnostic { DiagnosticDetailView(diagnostic: selectedDiagnostic) }
            }
            .onChange(of: environment.presentDiagnosticID) { _, id in
                guard let id, let diagnostic = allDiagnostics.first(where: { $0.id == id }) else { return }
                environment.presentDiagnosticID = nil
                open(diagnostic)
            }
        }
    }

    private func open(_ diagnostic: DiagnosticRecord) {
        selectedDiagnostic = diagnostic
        showDetails = true
    }

    @ViewBuilder private func actions(for diagnostic: DiagnosticRecord) -> some View {
        if diagnostic.isDeleted {
            Button { try? environment.store.restoreDiagnostic(diagnostic) } label: { Label("Restaurer", systemImage: "arrow.uturn.backward") }
        } else {
            if !diagnostic.resultMarkdown.isEmpty {
                Button {
                    Task {
                        do {
                            try await environment.api.sendDiagnosticResult(diagnostic)
                            environment.toast = ToastMessage(title: "Résultat envoyé", message: diagnostic.email, kind: .success)
                        } catch {
                            environment.toast = ToastMessage(title: "Envoi impossible", message: error.localizedDescription, kind: .error)
                        }
                    }
                } label: { Label("Envoyer le résultat", systemImage: "paperplane") }
            }
            Button(role: .destructive) { try? environment.store.moveDiagnosticToTrash(diagnostic) } label: { Label("Mettre à la corbeille", systemImage: "trash") }
        }
    }
}

private struct DiagnosticListRow: View {
    let diagnostic: DiagnosticRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(MyrtineTheme.accent.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text(String(diagnostic.firstName.prefix(1)) + String(diagnostic.lastName.prefix(1)))
                            .font(.body.weight(.bold))
                            .foregroundStyle(MyrtineTheme.accent)
                    }
                if !diagnostic.isRead && !diagnostic.isDeleted {
                    Circle().fill(MyrtineTheme.accent).frame(width: 12, height: 12).overlay { Circle().stroke(.white, lineWidth: 2) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(diagnostic.fullName.isEmpty ? diagnostic.email : diagnostic.fullName)
                        .font(.body.weight(diagnostic.isRead ? .regular : .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(diagnostic.updatedAt, format: .dateTime.day().month())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(diagnostic.projectObject).font(.subheadline).lineLimit(1)
                Text([diagnostic.email, diagnostic.phone].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Text(diagnostic.sector).lineLimit(1)
                    if !diagnostic.budget.isEmpty { Text("•"); Text(diagnostic.budget).lineLimit(1) }
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 86)
        .contentShape(Rectangle())
    }
}
