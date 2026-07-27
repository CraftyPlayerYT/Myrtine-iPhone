import SwiftUI

struct ConnectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isTesting = false
    @State private var latency: Int?
    @State private var detail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Surface {
                    HStack(spacing: 14) {
                        Image(systemName: environment.network.isOnline ? "checkmark.circle.fill" : "wifi.slash").font(.title).foregroundStyle(environment.network.isOnline ? MyrtineTheme.leaf : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(environment.network.isOnline ? "Connecté" : "Hors ligne").font(.title3.weight(.bold))
                            Text(environment.network.interfaceName).foregroundStyle(.secondary)
                        }
                    }
                    Divider().padding(.vertical, 6)
                    DetailLinePublic(label: "Serveur", value: MyrtineAPIClient.serverURL.absoluteString)
                    DetailLinePublic(label: "Durée de réponse", value: latency.map { "\($0) ms" } ?? "Non testée")
                    DetailLinePublic(label: "Dernière synchronisation", value: environment.lastSync?.formatted(date: .abbreviated, time: .shortened) ?? "Jamais")
                    if !detail.isEmpty { DetailLinePublic(label: "Résultat", value: detail) }
                }
                Button { test() } label: {
                    Group { if isTesting { ProgressView() } else { Label("Tester maintenant", systemImage: "bolt.horizontal.circle") } }
                }
                    .buttonStyle(PrimaryButtonStyle()).disabled(isTesting || !environment.network.isOnline).accessibilityIdentifier("connection-test")
                Button { Task { await environment.synchronize() } } label: { Label("Synchroniser les données", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(SecondaryButtonStyle()).disabled(environment.isSyncing || !environment.network.isOnline)
            }.padding(16)
        }.myrtineScreen().navigationTitle("Connexion").navigationBarTitleDisplayMode(.inline)
    }

    private func test() {
        isTesting = true
        Task {
            let start = ContinuousClock.now
            do {
                let (_, response) = try await URLSession.shared.data(from: MyrtineAPIClient.serverURL)
                let elapsed = start.duration(to: .now)
                latency = Int(Double(elapsed.components.attoseconds) / 1e15) + Int(elapsed.components.seconds * 1000)
                detail = (response as? HTTPURLResponse).map { "HTTP \($0.statusCode)" } ?? "Réponse reçue"
            } catch { detail = error.localizedDescription }
            isTesting = false
        }
    }
}
