import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Services") {
                    NavigationLink { ConnectionView() } label: { Label("Connexion et serveur", systemImage: "network") }.frame(minHeight: 48)
                    NavigationLink { CommunicationsView() } label: { Label("Appels et SMS", systemImage: "phone.bubble") }.frame(minHeight: 48)
                }
                Section("Application") {
                    NavigationLink { LogsView() } label: { Label("Journaux", systemImage: "list.bullet.rectangle") }.frame(minHeight: 48)
                    NavigationLink { SettingsView() } label: { Label("Réglages", systemImage: "gearshape") }.frame(minHeight: 48)
                    NavigationLink { AboutView() } label: { Label("À propos", systemImage: "info.circle") }.frame(minHeight: 48)
                }
            }
            .scrollContentBackground(.hidden)
            .myrtineScreen()
            .navigationTitle("Plus")
        }
    }
}

private struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("MyrtineMark").resizable().scaledToFit().frame(width: 112, height: 112).accessibilityLabel("Logo Myrtine")
                Text("Myrtine").font(.largeTitle.weight(.bold)).foregroundStyle(MyrtineTheme.ink)
                Text("Gestion interne des diagnostics de financements publics.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                Text("Version 1.0.0").font(.footnote).foregroundStyle(.tertiary)
            }.padding(30)
        }.myrtineScreen().navigationTitle("À propos").navigationBarTitleDisplayMode(.inline)
    }
}
