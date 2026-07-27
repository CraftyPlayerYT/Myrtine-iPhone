import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("textSizeLevel") private var textSizeLevel = 2

    var body: some View {
        @Bindable var environment = environment
        TabView(selection: $environment.selectedTab) {
            HomeView()
                .tag(AppEnvironment.SelectedTab.home)
                .tabItem { Label("Accueil", systemImage: "house") }

            DiagnosticsHomeView()
                .tag(AppEnvironment.SelectedTab.diagnostics)
                .tabItem { Label("Diagnostics", systemImage: "doc.text.magnifyingglass") }

            MailHomeView()
                .tag(AppEnvironment.SelectedTab.mail)
                .tabItem { Label("Messagerie", systemImage: "envelope") }

            ClientsView()
                .tag(AppEnvironment.SelectedTab.clients)
                .tabItem { Label("Clients", systemImage: "person.2") }

            MoreView()
                .tag(AppEnvironment.SelectedTab.more)
                .tabItem { Label("Plus", systemImage: "ellipsis") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !environment.network.isOnline {
                OfflineBanner()
            }
        }
        .overlay(alignment: .top) {
            if let toast = environment.toast {
                ToastView(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(4))
                        if environment.toast?.id == toast.id { environment.toast = nil }
                    }
            }
        }
        .animation(.snappy, value: environment.toast)
        .dynamicTypeSize(dynamicTypeSize)
        .transaction { transaction in
            if !animationsEnabled { transaction.animation = nil; transaction.disablesAnimations = true }
        }
        .onChange(of: environment.network.isOnline) { _, online in
            if online { Task { await environment.synchronize() } }
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch textSizeLevel {
        case 0: .small
        case 1: .medium
        case 3: .xLarge
        case 4: .xxLarge
        case 5: .xxxLarge
        default: .large
        }
    }
}

private struct OfflineBanner: View {
    var body: some View {
        Label("Hors ligne — vos modifications sont enregistrées sur cet iPhone", systemImage: "wifi.slash")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 36)
            .padding(.horizontal, 12)
            .background(Color.orange)
            .accessibilityIdentifier("offline-banner")
    }
}

private struct ToastView: View {
    let toast: ToastMessage

    private var color: Color {
        switch toast.kind {
        case .information: MyrtineTheme.accent
        case .success: MyrtineTheme.leaf
        case .warning: .orange
        case .error: .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.kind == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.subheadline.weight(.semibold))
                Text(toast.message).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.25)) }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}
