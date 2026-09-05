import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \DiagnosticRecord.updatedAt, order: .reverse) private var queriedDiagnostics: [DiagnosticRecord]
    @Query private var queriedClients: [ClientRecord]
    @Query private var queriedMessages: [MailMessageRecord]
    @State private var showNewDiagnostic = false

    private var activeDiagnostics: [DiagnosticRecord] { queriedDiagnostics.filter { !$0.isTrashed } }
    private var unread: [DiagnosticRecord] { activeDiagnostics.filter { !$0.isRead && !$0.resultMarkdown.isEmpty } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    connectionHeader
                    metrics
                    recentDiagnostics
                }
                .padding(16)
            }
            .myrtineScreen()
            .navigationTitle("Myrtine")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await environment.synchronize() } } label: {
                        if environment.isSyncing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(environment.isSyncing || !environment.network.isOnline)
                    .accessibilityLabel("Synchroniser")
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { showNewDiagnostic = true } label: {
                    Label("Nouveau diagnostic", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("home-new-diagnostic")
            }
            .fullScreenCover(isPresented: $showNewDiagnostic) { NewDiagnosticView() }
        }
    }

    private var connectionHeader: some View {
        Surface {
            HStack(spacing: 14) {
                Image(systemName: environment.network.isOnline ? "checkmark.circle.fill" : "wifi.slash")
                    .font(.title2)
                    .foregroundStyle(environment.network.isOnline ? MyrtineTheme.leaf : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(environment.network.isOnline ? "Services disponibles" : "Mode hors ligne")
                        .font(.headline)
                    Text(environment.network.isOnline ? "Connexion \(environment.network.interfaceName) active" : "Consultation et saisie locales disponibles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Diagnostics", value: "\(activeDiagnostics.count)", systemImage: "doc.text")
            MetricTile(title: "Non lus", value: "\(unread.count)", systemImage: "sparkles", tint: .orange)
            MetricTile(title: "Clients", value: "\(queriedClients.count)", systemImage: "person.2", tint: MyrtineTheme.leaf)
            MetricTile(title: "E-mails", value: "\(queriedMessages.filter { !$0.isTrashed }.count)", systemImage: "envelope", tint: MyrtineTheme.blueberry)
        }
    }

    @ViewBuilder private var recentDiagnostics: some View {
        Surface {
            Text("Diagnostics récents").font(.title3.weight(.bold))
            if activeDiagnostics.isEmpty {
                Text("Aucun diagnostic pour le moment.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(activeDiagnostics.prefix(4)) { diagnostic in
                    Divider()
                    Button {
                        environment.selectedTab = .diagnostics
                        environment.presentDiagnosticID = diagnostic.id
                    } label: {
                        DiagnosticCompactRow(diagnostic: diagnostic)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = MyrtineTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage).font(.title3).foregroundStyle(tint)
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(MyrtineTheme.ink)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(MyrtineTheme.divider) }
    }
}

struct DiagnosticCompactRow: View {
    let diagnostic: DiagnosticRecord
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(diagnostic.isRead ? MyrtineTheme.divider : MyrtineTheme.accent.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay { Text(compactInitials).font(.subheadline.weight(.bold)).foregroundStyle(MyrtineTheme.accent) }
            VStack(alignment: .leading, spacing: 3) {
                Text(diagnostic.displayTitle).font(.body.weight(diagnostic.isRead ? .regular : .semibold)).lineLimit(1)
                Text(diagnostic.projectObject).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Text([diagnostic.sector, diagnostic.budget].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: diagnostic.state.systemImage)
                .font(.subheadline)
                .foregroundStyle(diagnostic.state == .failed ? .red : MyrtineTheme.accent)
                .accessibilityLabel(diagnostic.state.rawValue)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 58)
    }

    private var compactInitials: String {
        diagnostic.displayInitials
    }
}
