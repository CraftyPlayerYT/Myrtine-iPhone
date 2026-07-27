import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("textSizeLevel") private var textSizeLevel = 2
    @State private var perplexityKey = ""
    @State private var keySaved = false

    var body: some View {
        Form {
            Section("Affichage") {
                Toggle("Animations", isOn: $animationsEnabled).frame(minHeight: 48)
                Picker("Taille du texte", selection: $textSizeLevel) {
                    Text("Petite").tag(0); Text("Normale").tag(2); Text("Grande").tag(3); Text("Très grande").tag(5)
                }.frame(minHeight: 48)
            }
            Section("Réseau et tests") {
                Picker("État du réseau", selection: Binding(get: { environment.network.simulation }, set: { environment.network.simulation = $0 })) {
                    ForEach(NetworkMonitor.Simulation.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Erreur simulée", selection: Binding(get: { environment.api.simulatedFailure }, set: { environment.api.simulatedFailure = $0 })) {
                    ForEach(MyrtineAPIClient.SimulationFailure.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("Les simulations n'envoient aucune requête lorsqu'elles sont combinées au mode de test de l'application.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Intelligence artificielle") {
                SecureField("Clé Perplexity", text: $perplexityKey).textContentType(.password).frame(minHeight: 48)
                Button(keySaved ? "Clé enregistrée" : "Enregistrer dans le Trousseau") { saveKey() }.disabled(perplexityKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if KeychainStore.get(MyrtineAPIClient.perplexityKeyAccount) != nil {
                    Button("Supprimer la clé", role: .destructive) { KeychainStore.remove(MyrtineAPIClient.perplexityKeyAccount); perplexityKey = ""; keySaved = false }
                }
                Text("Avec une clé, l'iPhone interroge Sonar Pro directement. En cas d'échec, le serveur Myrtine prend le relais et inscrit l'erreur dans les journaux.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Réglages").navigationBarTitleDisplayMode(.inline)
        .onAppear { keySaved = KeychainStore.get(MyrtineAPIClient.perplexityKeyAccount) != nil }
    }

    private func saveKey() {
        do { try KeychainStore.set(perplexityKey.trimmingCharacters(in: .whitespacesAndNewlines), for: MyrtineAPIClient.perplexityKeyAccount); perplexityKey = ""; keySaved = true; environment.toast = ToastMessage(title: "Clé enregistrée", message: "Elle est protégée par le Trousseau iOS.", kind: .success) }
        catch { environment.toast = ToastMessage(title: "Trousseau indisponible", message: error.localizedDescription, kind: .error) }
    }
}
