import SwiftUI
import UIKit

struct NewDiagnosticView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    private let editingRecord: DiagnosticRecord?
    @State private var draft: DiagnosticDraft
    @State private var newExpense = ""
    @State private var isSending = false
    @State private var submissionTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var keyboardVisible = false

    init(diagnostic: DiagnosticRecord? = nil) {
        editingRecord = diagnostic
        let isPrefilledUITest = ProcessInfo.processInfo.arguments.contains("-prefill-diagnostic")
        _draft = State(initialValue: diagnostic.map(DiagnosticDraft.init) ?? (isPrefilledUITest ? .uiTestSample : DiagnosticDraft()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    projectSection
                    expenseSection
                    additionalInformationSection
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("diagnostic-error")
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .myrtineScreen()
            .navigationTitle(editingRecord == nil ? "Nouveau diagnostic" : "Modifier le brouillon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { cancelAndDismiss() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("diagnostic-close")
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Terminer") { dismissKeyboard() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("diagnostic-keyboard-done")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible {
                    actionBar
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .interactiveDismissDisabled(isSending)
        }
    }

    private var projectSection: some View {
        Surface {
            Text("Projet").font(.title3.weight(.bold))
            FormField("Titre du diagnostic", required: true, text: $draft.title)
            FormField("Objet du projet", required: true, text: $draft.projectObject, axis: .vertical)
            FormField("Porteur du projet", required: true, text: $draft.projectOwner, axis: .vertical)
            FormField("Secteur d'activité", required: true, text: $draft.sector)
            FormField("Localisation", required: true, text: $draft.location)
            FormField("Effectif", required: true, text: $draft.workforce)
            FormField("Chiffre d'affaires", text: $draft.revenue)
            FormField("Budget prévisionnel", required: true, text: $draft.budget)
            FormField("Calendrier", required: true, text: $draft.schedule, axis: .vertical)
        }
    }

    private var expenseSection: some View {
        Surface {
            Text("Dépenses concernées").font(.title3.weight(.bold))
            ForEach(Array(draft.expenses.enumerated()), id: \.offset) { index, expense in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(MyrtineTheme.leaf)
                    Text(expense).font(.body)
                    Spacer()
                    Button { draft.expenses.remove(at: index) } label: { Image(systemName: "xmark") }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Supprimer \(expense)")
                }
            }
            HStack(spacing: 10) {
                TextField("Ajouter une dépense", text: $newExpense)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("diagnostic-expense")
                Button { addExpense() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 48, minHeight: 48)
                    .disabled(newExpense.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Ajouter la dépense")
            }
        }
    }

    private var additionalInformationSection: some View {
        Surface {
            Text("Informations supplémentaires").font(.title3.weight(.bold))
            FormField("Précisions utiles sur le projet", text: $draft.additionalInformation, axis: .vertical)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            if isSending {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Recherche des financements en cours…").font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Annuler") { submissionTask?.cancel(); isSending = false }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                }
            } else {
                Button { submit() } label: {
                    Label(environment.network.isOnline ? "Lancer le diagnostic" : "Mettre en attente", systemImage: environment.network.isOnline ? "sparkles" : "clock")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!draft.isComplete)
                .accessibilityIdentifier("diagnostic-submit")

                HStack(spacing: 12) {
                    Button(editingRecord == nil ? "Enregistrer le brouillon" : "Enregistrer les modifications") { saveDraftAndDismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("diagnostic-save-draft")
                    Button("Annuler", role: .cancel) { cancelAndDismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("diagnostic-cancel")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func addExpense() {
        let value = newExpense.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        draft.expenses.append(value)
        newExpense = ""
    }

    private func makeRecord() -> DiagnosticRecord {
        let record = editingRecord ?? DiagnosticRecord()
        draft.apply(to: record)
        return record
    }

    private func saveDraftAndDismiss() {
        guard draft.hasTitle else {
            errorMessage = "Donnez un titre au brouillon avant de l'enregistrer."
            return
        }
        do {
            let record = makeRecord()
            record.state = .draft
            try environment.store.saveDiagnostic(record)
            environment.toast = ToastMessage(title: "Brouillon enregistré", message: "Il reste disponible hors ligne.", kind: .success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() {
        errorMessage = nil
        isSending = true
        let record = makeRecord()
        do { try environment.store.saveDiagnostic(record) } catch { errorMessage = error.localizedDescription; isSending = false; return }
        submissionTask = Task {
            do {
                try await environment.sync.submit(record)
                guard !Task.isCancelled else { return }
                isSending = false
                environment.selectedTab = .diagnostics
                environment.toast = ToastMessage(title: environment.network.isOnline ? "Diagnostic reçu" : "Diagnostic mis en attente", message: environment.network.isOnline ? "Le résultat est prêt." : "Il sera envoyé à la reconnexion.", kind: .success)
                dismiss()
                try? await Task.sleep(for: .milliseconds(350))
                environment.presentDiagnosticID = record.id
            } catch is CancellationError {
                isSending = false
            } catch {
                record.lastError = error.localizedDescription
                errorMessage = error.localizedDescription
                isSending = false
            }
        }
    }

    private func cancelAndDismiss() {
        submissionTask?.cancel()
        dismiss()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct FormField: View {
    let title: String
    let required: Bool
    @Binding var text: String
    let axis: Axis
    let contentType: UITextContentType?
    let keyboard: UIKeyboardType

    init(_ title: String, required: Bool = false, text: Binding<String>, axis: Axis = .horizontal, contentType: UITextContentType? = nil, keyboard: UIKeyboardType = .default) {
        self.title = title; self.required = required; _text = text; self.axis = axis; self.contentType = contentType; self.keyboard = keyboard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title + (required ? " *" : "")).font(.subheadline.weight(.medium))
            TextField(title, text: $text, axis: axis)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .lineLimit(axis == .vertical ? 2...5 : 1...1)
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(MyrtineTheme.divider) }
                .accessibilityIdentifier("field-\(title)")
        }
        .padding(.top, 6)
    }
}

private struct DiagnosticDraft {
    var title = ""
    var projectObject = ""
    var projectOwner = ""
    var sector = ""
    var location = ""
    var workforce = ""
    var revenue = ""
    var budget = ""
    var schedule = ""
    var expenses: [String] = []
    var additionalInformation = ""

    init(
        title: String = "",
        projectObject: String = "",
        projectOwner: String = "",
        sector: String = "",
        location: String = "",
        workforce: String = "",
        revenue: String = "",
        budget: String = "",
        schedule: String = "",
        expenses: [String] = [],
        additionalInformation: String = ""
    ) {
        self.title = title
        self.projectObject = projectObject
        self.projectOwner = projectOwner
        self.sector = sector
        self.location = location
        self.workforce = workforce
        self.revenue = revenue
        self.budget = budget
        self.schedule = schedule
        self.expenses = expenses
        self.additionalInformation = additionalInformation
    }

    init(_ record: DiagnosticRecord) {
        title = record.title
        projectObject = record.projectObject
        projectOwner = record.projectOwner
        sector = record.sector
        location = record.location
        workforce = record.workforce
        revenue = record.revenue
        budget = record.budget
        schedule = record.schedule
        expenses = record.expenses
        additionalInformation = record.additionalInformation
    }

    var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isComplete: Bool {
        hasTitle && [projectObject, projectOwner, sector, location, workforce, budget, schedule].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && !expenses.isEmpty
    }

    func apply(to record: DiagnosticRecord) {
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.projectObject = projectObject
        record.projectOwner = projectOwner
        record.sector = sector
        record.location = location
        record.workforce = workforce
        record.revenue = revenue
        record.budget = budget
        record.schedule = schedule
        record.expenses = expenses
        record.additionalInformation = additionalInformation
    }

    static let uiTestSample = DiagnosticDraft(
        title: "Atelier Test - Énergie 2027",
        projectObject: "Réduction énergétique de la ligne de production",
        projectOwner: "Atelier Test iOS",
        sector: "Industrie manufacturière",
        location: "Lyon, Auvergne-Rhône-Alpes",
        workforce: "12 salariés",
        revenue: "900 000 €",
        budget: "150 000 € HT",
        schedule: "Deuxième trimestre 2027",
        expenses: ["Machines moins énergivores"],
        additionalInformation: "Le bâtiment est déjà raccordé au réseau de chaleur."
    )
}
