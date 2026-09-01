import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab: GlassTab = .home
    @State private var isComposerPresented = false
    @State private var toastMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackground()

            Group {
                switch selectedTab {
                case .home:
                    HomeScreen(showComposer: showComposer, showToast: showToast)
                case .tasks:
                    TasksScreen(showComposer: showComposer, showToast: showToast)
                case .insights:
                    InsightsScreen(showToast: showToast)
                case .profile:
                    ProfileScreen(showToast: showToast)
                }
            }
            .transition(.opacity)

            GlassTabBar(selectedTab: $selectedTab, showComposer: showComposer)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isComposerPresented) {
            QuickAddSheet { title in
                isComposerPresented = false
                showToast("\(title) ajouté")
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func showComposer() {
        Haptics.light()
        isComposerPresented = true
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

private enum GlassTab: String, CaseIterable, Identifiable {
    case home
    case tasks
    case insights
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Accueil"
        case .tasks: return "Tâches"
        case .insights: return "Bilan"
        case .profile: return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .tasks: return "checkmark.circle.fill"
        case .insights: return "chart.bar.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

private struct GlassBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.94, green: 0.96, blue: 0.99)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.9),
                    Color(red: 0.91, green: 0.96, blue: 0.98).opacity(0.72),
                    Color(red: 0.96, green: 0.94, blue: 0.99).opacity(0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct HomeScreen: View {
    let showComposer: () -> Void
    let showToast: (String) -> Void

    @State private var tasks = SampleData.tasks
    @State private var focusProgress = 0.68

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: "MARDI 1 SEPTEMBRE",
                    title: "Bonjour Maxime",
                    subtitle: "Voici l’essentiel de votre journée."
                ) {
                    showToast("Tout est synchronisé")
                }

                FocusCard(progress: focusProgress) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        focusProgress = focusProgress > 0.9 ? 0.12 : min(1, focusProgress + 0.12)
                    }
                    Haptics.medium()
                }

                HStack(spacing: 12) {
                    MetricCard(value: "6", label: "À faire", icon: "checklist", tint: .blue)
                    MetricCard(value: "42 min", label: "Concentration", icon: "timer", tint: .green)
                }

                SectionTitle(title: "À suivre", action: "Tout voir") {
                    showToast("Liste complète ouverte")
                }

                VStack(spacing: 10) {
                    ForEach(Array(tasks.indices.prefix(3)), id: \.self) { index in
                        TaskRow(task: $tasks[index])
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 112)
        }
    }
}

private struct TasksScreen: View {
    let showComposer: () -> Void
    let showToast: (String) -> Void

    @State private var selectedFilter = 0
    @State private var tasks = SampleData.tasks

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: "ORGANISATION",
                    title: "Mes tâches",
                    subtitle: "Avancez sans perdre le fil."
                ) {
                    showComposer()
                }

                GlassSegmentedControl(
                    options: ["Aujourd’hui", "Semaine", "Toutes"],
                    selection: $selectedFilter
                )

                VStack(spacing: 10) {
                    ForEach($tasks) { $task in
                        TaskRow(task: $task)
                    }
                }

                Button {
                    showComposer()
                } label: {
                    Label("Ajouter une tâche", systemImage: "plus")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryGlassButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 112)
        }
    }
}

private struct InsightsScreen: View {
    let showToast: (String) -> Void

    @State private var selectedPeriod = 1

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: "VOTRE RYTHME",
                    title: "Bilan",
                    subtitle: "Une vue claire de vos progrès."
                ) {
                    showToast("Bilan actualisé")
                }

                GlassSegmentedControl(
                    options: ["Jour", "Semaine", "Mois"],
                    selection: $selectedPeriod
                )

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Temps productif")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("5 h 24")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                        }

                        Spacer()

                        Text("+18 %")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    WeeklyChart(values: [0.42, 0.64, 0.51, 0.86, 0.72, 0.38, 0.61])
                }
                .glassSurface(cornerRadius: 22)

                HStack(spacing: 12) {
                    MetricCard(value: "14", label: "Terminées", icon: "checkmark", tint: .green)
                    MetricCard(value: "3", label: "En cours", icon: "arrow.triangle.2.circlepath", tint: .orange)
                }

                VStack(alignment: .leading, spacing: 13) {
                    Text("Conseil du jour")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Gardez vos tâches importantes dans un seul créneau de concentration, puis réservez dix minutes pour faire le point.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .glassSurface(cornerRadius: 22, tint: Color.orange.opacity(0.07))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 112)
        }
    }
}

private struct ProfileScreen: View {
    let showToast: (String) -> Void

    @AppStorage("legacyGlassNotifications") private var notificationsEnabled = true
    @AppStorage("legacyGlassHaptics") private var hapticsEnabled = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: "PRÉFÉRENCES",
                    title: "Profil",
                    subtitle: "Réglez l’expérience à votre façon."
                ) {
                    showToast("Profil à jour")
                }

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.14))
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.indigo)
                    }
                    .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maxime")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Compte de démonstration")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .glassSurface(cornerRadius: 22)

                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Notifications",
                        subtitle: "Rappels et activité",
                        icon: "bell.fill",
                        tint: .blue,
                        isOn: $notificationsEnabled
                    )

                    Divider().padding(.leading, 54)

                    SettingsToggleRow(
                        title: "Retours haptiques",
                        subtitle: "Vibrations légères",
                        icon: "hand.tap.fill",
                        tint: .purple,
                        isOn: $hapticsEnabled
                    )
                }
                .glassSurface(cornerRadius: 22, contentPadding: 4)

                VStack(spacing: 0) {
                    SettingsButtonRow(title: "Apparence", icon: "paintbrush.fill", tint: .orange) {
                        showToast("Thème clair sélectionné")
                    }
                    Divider().padding(.leading, 54)
                    SettingsButtonRow(title: "À propos", icon: "info.circle.fill", tint: .green) {
                        showToast("Myrtine Glass · iOS 16")
                    }
                }
                .glassSurface(cornerRadius: 22, contentPadding: 4)

                Text("Interface de démonstration conçue pour iPhone 8 sous iOS 16.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 112)
        }
    }
}

private struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.indigo)
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .glassCircle()
            }
            .buttonStyle(PressedScaleButtonStyle())
            .accessibilityLabel("Actualiser")
        }
    }
}

private struct FocusCard: View {
    let progress: Double
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Priorité du jour", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.indigo)
                Spacer()
                Text("\(Int(progress * 100)) %")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text("Finaliser la présentation")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.07))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo, Color.blue, Color.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)

            Button(action: action) {
                Label("Faire avancer", systemImage: "arrow.up.right")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PrimaryGlassButtonStyle())
        }
        .glassSurface(cornerRadius: 24, tint: Color.indigo.opacity(0.055))
    }
}

private struct MetricCard: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 20)
    }
}

private struct SectionTitle: View {
    let title: String
    let action: String
    let handler: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            Button(action, action: handler)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.indigo)
        }
    }
}

private struct TaskItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
    var isDone: Bool
}

private struct TaskRow: View {
    @Binding var task: TaskItem

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                task.isDone.toggle()
            }
            Haptics.light()
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(task.isDone ? task.tint : Color.clear)
                        .overlay(Circle().stroke(task.tint.opacity(0.7), lineWidth: 1.5))
                    if task.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 27, height: 27)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                        .strikethrough(task.isDone, color: .secondary)
                    Text(task.detail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.55))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: 18, contentPadding: 14)
    }
}

private struct GlassSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = index
                    }
                    Haptics.light()
                } label: {
                    Text(options[index])
                        .font(.system(size: 13, weight: selection == index ? .bold : .medium, design: .rounded))
                        .foregroundStyle(selection == index ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.76))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.95), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.09), radius: 7, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct WeeklyChart: View {
    let values: [Double]
    private let labels = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(values.indices, id: \.self) { index in
                VStack(spacing: 7) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(index == 3 ? Color.indigo : Color.blue.opacity(0.28))
                                .frame(height: max(8, proxy.size.height * values[index]))
                        }
                    }
                    .frame(height: 112)

                    Text(labels[index])
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(index == 3 ? Color.indigo : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 32, height: 32)
                .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.indigo)
        }
        .padding(10)
    }
}

private struct SettingsButtonRow: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.55))
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GlassTabBar: View {
    @Binding var selectedTab: GlassTab
    let showComposer: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(GlassTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                    Haptics.light()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.indigo : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                                )
                                .shadow(color: Color.indigo.opacity(0.14), radius: 8, y: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }

            Button(action: showComposer) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.indigo.opacity(0.32), radius: 10, y: 5)
            }
            .buttonStyle(PressedScaleButtonStyle())
            .accessibilityLabel("Ajouter")
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.13), radius: 18, y: 8)
    }
}

private struct QuickAddSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @FocusState private var titleIsFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Nouvelle tâche")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("Ajoutez quelque chose à votre journée.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                TextField("Ex. Préparer le rendez-vous", text: $title)
                    .font(.system(size: 16, design: .rounded))
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(titleIsFocused ? Color.indigo : Color.black.opacity(0.08), lineWidth: 1.3)
                    )
                    .focused($titleIsFocused)
                    .submitLabel(.done)
                    .onSubmit(add)

                Button(action: add) {
                    Text("Ajouter")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryGlassButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleIsFocused = true
            }
        }
    }

    private func add() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        Haptics.medium()
        onAdd(cleanTitle)
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let contentPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(contentPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(tint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), Color.white.opacity(0.35), Color.black.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.075), radius: 14, y: 7)
    }
}

private extension View {
    func glassSurface(
        cornerRadius: CGFloat,
        tint: Color = .clear,
        contentPadding: CGFloat = 16
    ) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius, tint: tint, contentPadding: contentPadding))
    }

    func glassCircle() -> some View {
        background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.09), radius: 10, y: 4)
    }
}

private struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                LinearGradient(
                    colors: [Color.indigo, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: Color.indigo.opacity(configuration.isPressed ? 0.12 : 0.28), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum SampleData {
    static let tasks = [
        TaskItem(title: "Préparer le rendez-vous", detail: "09:30 · 25 minutes", tint: .indigo, isDone: false),
        TaskItem(title: "Relire la proposition", detail: "Avant 14:00", tint: .blue, isDone: true),
        TaskItem(title: "Répondre à Camille", detail: "Message important", tint: .green, isDone: false),
        TaskItem(title: "Classer les documents", detail: "Cette semaine", tint: .orange, isDone: false),
        TaskItem(title: "Mettre à jour le planning", detail: "Vendredi", tint: .purple, isDone: false)
    ]
}

private enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
