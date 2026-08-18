import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("textSizeLevel") private var textSizeLevel = 2

    var body: some View {
        @Bindable var environment = environment
        Group {
            if environment.isActivated {
                applicationTabs(environment: environment)
            } else {
                ActivationView()
            }
        }
        .animation(.smooth, value: environment.isActivated)
    }

    @ViewBuilder
    private func applicationTabs(environment: AppEnvironment) -> some View {
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let destination = toast.destination {
                            environment.open(destination)
                            environment.toast = nil
                        }
                    }
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

private struct ActivationView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var code = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            MyrtineTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Image("MyrtineMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Activer Myrtine")
                            .font(.largeTitle.bold())
                            .foregroundStyle(MyrtineTheme.ink)
                        Text("Saisissez le code d’accès administrateur. La vérification est effectuée uniquement par le serveur Myrtine.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Code d’accès")
                            .font(.subheadline.weight(.semibold))
                        ActivationCodeTextField(text: $code)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(MyrtineTheme.accent.opacity(0.5), lineWidth: 1.5) }
                            .accessibilityIdentifier("activation-code")
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button { activate() } label: {
                        if isChecking { ProgressView().tint(.white) }
                        else { Label("Vérifier et activer", systemImage: "checkmark.shield.fill") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isChecking || !ActivationCodeFormatter.isComplete(code) || !environment.network.isOnline)
                    .accessibilityIdentifier("activation-submit")

                    if !environment.network.isOnline {
                        Label("Une connexion Internet est nécessaire pour la première activation.", systemImage: "wifi.slash")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 56)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func activate() {
        isChecking = true
        errorMessage = nil
        Task {
            do { try await environment.activate(code: code) }
            catch { errorMessage = error.localizedDescription }
            isChecking = false
        }
    }
}

enum ActivationCodeFormatter {
    private static let digitsPerGroup = 6
    private static let digitCount = 18

    static func format(_ value: String) -> String {
        let digits = Array(value.filter { "0123456789".contains($0) }.prefix(digitCount))
        return stride(from: 0, to: digits.count, by: digitsPerGroup)
            .map { start in
                let end = min(start + digitsPerGroup, digits.count)
                return String(digits[start..<end])
            }
            .joined(separator: "-")
    }

    static func isComplete(_ value: String) -> Bool {
        format(value).count == digitCount + 2
    }
}

private struct ActivationCodeTextField: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.placeholder = "000000-000000-000000"
        field.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityIdentifier = "activation-code"
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        // Do not replay a slightly stale SwiftUI binding while UIKit is
        // processing a fast sequence of number-pad keystrokes.
        if !uiView.isFirstResponder, uiView.text != text {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ActivationCodeTextField

        init(_ parent: ActivationCodeTextField) {
            self.parent = parent
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else {
                return false
            }

            let replacement = current.replacingCharacters(in: swiftRange, with: string)
            let formatted = ActivationCodeFormatter.format(replacement)
            textField.text = formatted
            parent.text = formatted
            return false
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
