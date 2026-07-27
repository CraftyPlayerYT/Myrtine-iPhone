import SwiftUI
import SwiftData

struct LogsView: View {
    @Query(sort: \LogRecord.date, order: .reverse) private var logs: [LogRecord]
    @State private var search = ""

    private var filtered: [LogRecord] { logs.filter { search.isEmpty || [$0.level, $0.category, $0.message, $0.detail].contains { $0.localizedCaseInsensitiveContains(search) } } }

    var body: some View {
        Group {
            if filtered.isEmpty { EmptyStateView(systemImage: "list.bullet.rectangle", title: "Aucun journal", message: "Les événements réseau et les erreurs apparaîtront ici.") }
            else {
                List(filtered) { entry in
                    DisclosureGroup {
                        if !entry.detail.isEmpty { Text(entry.detail).font(.caption.monospaced()).textSelection(.enabled).padding(.vertical, 8) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Circle().fill(color(entry.level)).frame(width: 10, height: 10).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 4) { Text(entry.message).font(.subheadline.weight(.medium)); Text("\(entry.category) · \(entry.date.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }
                }.listStyle(.plain)
            }
        }.myrtineScreen().navigationTitle("Journaux").navigationBarTitleDisplayMode(.inline).searchable(text: $search)
    }

    private func color(_ level: String) -> Color { level == "Erreur" ? .red : level == "Avertissement" ? .orange : MyrtineTheme.accent }
}
