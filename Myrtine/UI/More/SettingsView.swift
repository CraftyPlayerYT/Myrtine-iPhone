import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("textSizeLevel") private var textSizeLevel = 2

    var body: some View {
        Form {
            Section("Affichage") {
                Toggle("Animations", isOn: $animationsEnabled).frame(minHeight: 48)
                Picker("Taille du texte", selection: $textSizeLevel) {
                    Text("Petite").tag(0); Text("Normale").tag(2); Text("Grande").tag(3); Text("Très grande").tag(5)
                }.frame(minHeight: 48)
            }
            #if DEBUG
            Section("Simulations de test") {
                Picker("État du réseau", selection: Binding(get: { environment.network.simulation }, set: { environment.network.simulation = $0 })) {
                    ForEach(NetworkMonitor.Simulation.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Erreur simulée", selection: Binding(get: { environment.api.simulatedFailure }, set: { environment.api.simulatedFailure = $0 })) {
                    ForEach(MyrtineAPIClient.SimulationFailure.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("Les simulations n'envoient aucune requête lorsqu'elles sont combinées au mode de test de l'application.").font(.footnote).foregroundStyle(.secondary)
            }
            #endif
            Section("Sécurité") {
                LabeledContent("Activation") {
                    Label("Validée", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(MyrtineTheme.leaf)
                }
                .frame(minHeight: 48)
                Text("Aucune clé Supabase ou IA n'est enregistrée dans l'application. Chaque service passe par le serveur Myrtine avec le jeton protégé par le Trousseau iOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Réglages").navigationBarTitleDisplayMode(.inline)
    }
}
