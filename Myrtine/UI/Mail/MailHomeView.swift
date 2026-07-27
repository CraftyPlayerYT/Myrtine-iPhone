import SwiftUI
import SwiftData

struct MailHomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \MailFolderRecord.sortOrder) private var allFolders: [MailFolderRecord]
    @Query(sort: \MailMessageRecord.createdAt, order: .reverse) private var allMessages: [MailMessageRecord]
    @State private var showCompose = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var editFolder: MailFolderRecord?
    @State private var editFolderName = ""
    @State private var errorMessage: String?

    private var folders: [MailFolderRecord] { allFolders.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showCompose = true } label: {
                        Label("Nouveau message", systemImage: "square.and.pencil")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .listRowBackground(MyrtineTheme.accent)
                    .accessibilityIdentifier("mail-compose")
                }

                Section("contact@myrtine.fr") {
                    ForEach(folders) { folder in
                        NavigationLink {
                            MailFolderView(folder: folder)
                        } label: {
                            FolderRow(folder: folder, count: messageCount(folder), unread: unreadCount(folder))
                        }
                        .contextMenu {
                            if folder.kind == "custom" {
                                Button { beginRename(folder) } label: { Label("Renommer", systemImage: "pencil") }
                                Button(role: .destructive) { delete(folder) } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if folder.kind == "custom" {
                                Button(role: .destructive) { delete(folder) } label: { Label("Supprimer", systemImage: "trash") }
                                Button { beginRename(folder) } label: { Label("Renommer", systemImage: "pencil") }.tint(MyrtineTheme.accent)
                            }
                        }
                    }
                }

                Section {
                    Button { showCreateFolder = true } label: { Label("Créer un dossier", systemImage: "folder.badge.plus").frame(minHeight: 44) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .myrtineScreen()
            .navigationTitle("Messagerie")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await environment.synchronize() } } label: {
                        Group { if environment.isSyncing { ProgressView() } else { Image(systemName: "arrow.clockwise") } }
                    }
                        .disabled(environment.isSyncing || !environment.network.isOnline)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Synchroniser la messagerie")
                }
            }
            .fullScreenCover(isPresented: $showCompose) { ComposeMailView() }
            .alert("Nouveau dossier", isPresented: $showCreateFolder) {
                TextField("Nom du dossier", text: $newFolderName)
                Button("Annuler", role: .cancel) { newFolderName = "" }
                Button("Créer") { createFolder() }
            }
            .alert("Renommer le dossier", isPresented: Binding(get: { editFolder != nil }, set: { if !$0 { editFolder = nil } })) {
                TextField("Nom du dossier", text: $editFolderName)
                Button("Annuler", role: .cancel) { editFolder = nil }
                Button("Renommer") { renameFolder() }
            }
            .alert("Action impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Erreur inconnue") }
        }
    }

    private func messageCount(_ folder: MailFolderRecord) -> Int {
        if folder.kind == "trash" { return allMessages.filter { $0.isDeleted }.count + allFolders.filter { $0.isDeleted }.count }
        return allMessages.filter { !$0.isDeleted && $0.folderName == folder.name }.count
    }

    private func unreadCount(_ folder: MailFolderRecord) -> Int {
        allMessages.filter { !$0.isDeleted && $0.folderName == folder.name && !$0.isRead }.count
    }

    private func createFolder() {
        do { _ = try environment.store.createFolder(name: newFolderName); newFolderName = "" }
        catch { errorMessage = error.localizedDescription }
    }

    private func beginRename(_ folder: MailFolderRecord) { editFolder = folder; editFolderName = folder.name }

    private func renameFolder() {
        guard let editFolder else { return }
        do { try environment.store.renameFolder(editFolder, to: editFolderName); self.editFolder = nil }
        catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ folder: MailFolderRecord) {
        do { try environment.store.moveFolderToTrash(folder); environment.toast = ToastMessage(title: "Dossier supprimé", message: "Il peut être restauré depuis la corbeille.", kind: .information) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct FolderRow: View {
    let folder: MailFolderRecord
    let count: Int
    let unread: Int
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: folder.systemImage).font(.title3).foregroundStyle(folder.kind == "priority" ? .yellow : MyrtineTheme.accent).frame(width: 28)
            Text(folder.name).font(.body.weight(unread > 0 ? .semibold : .regular))
            Spacer()
            if unread > 0 { Text("\(unread)").font(.caption.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(MyrtineTheme.accent, in: Capsule()) }
            else if count > 0 { Text("\(count)").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }
}

struct MailFolderView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \MailMessageRecord.createdAt, order: .reverse) private var allMessages: [MailMessageRecord]
    @Query(sort: \MailFolderRecord.updatedAt, order: .reverse) private var allFolders: [MailFolderRecord]
    let folder: MailFolderRecord
    @State private var search = ""
    @State private var selected: MailMessageRecord?
    @State private var showMessage = false
    @State private var showCompose = false

    private var messages: [MailMessageRecord] {
        allMessages.filter { message in
            let belongs = folder.kind == "trash" ? message.isDeleted : !message.isDeleted && message.folderName == folder.name
            return belongs && (search.isEmpty || [message.correspondent, message.subject, message.body].contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }
    private var deletedFolders: [MailFolderRecord] { folder.kind == "trash" ? allFolders.filter { $0.isDeleted } : [] }

    var body: some View {
        Group {
            if messages.isEmpty && deletedFolders.isEmpty {
                EmptyStateView(systemImage: folder.systemImage, title: "Dossier vide", message: "Aucun message dans \(folder.name).")
                    .myrtineScreen()
            } else {
                List {
                    if !deletedFolders.isEmpty {
                        Section("Dossiers supprimés") {
                            ForEach(deletedFolders) { deleted in
                                NavigationLink { DeletedFolderView(folder: deleted) } label: {
                                    Label(deleted.name, systemImage: "folder").frame(minHeight: 48)
                                }
                                .swipeActions {
                                    Button { try? environment.store.restoreFolder(deleted) } label: { Label("Restaurer", systemImage: "arrow.uturn.backward") }.tint(MyrtineTheme.leaf)
                                }
                            }
                        }
                    }
                    Section(messages.isEmpty ? "" : "Messages") {
                        ForEach(messages) { message in
                            HStack(spacing: 8) {
                                Button { open(message) } label: { MessageRow(message: message) }.buttonStyle(.plain)
                                Menu {
                                    Button { open(message) } label: { Label("Ouvrir", systemImage: "envelope.open") }
                                    if message.isDeleted {
                                        Button { try? environment.store.restoreMessage(message) } label: { Label("Restaurer", systemImage: "arrow.uturn.backward") }
                                        Button(role: .destructive) { try? environment.store.deletePermanently(message) } label: { Label("Supprimer définitivement", systemImage: "trash.slash") }
                                    } else {
                                        Button { try? environment.store.moveMessage(message, to: "Archives") } label: { Label("Archiver", systemImage: "archivebox") }
                                        Button(role: .destructive) { try? environment.store.moveMessage(message, to: "Corbeille") } label: { Label("Supprimer", systemImage: "trash") }
                                    }
                                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                                .accessibilityLabel("Actions pour \(message.subject)")
                            }
                            .listRowBackground(message.isRead ? Color.white : MyrtineTheme.accent.opacity(0.055))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .myrtineScreen()
                .refreshable { await environment.synchronize() }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Rechercher dans ce dossier")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }.frame(minWidth: 44, minHeight: 44).accessibilityLabel("Nouveau message")
            }
        }
        .fullScreenCover(isPresented: $showCompose) { ComposeMailView() }
        .fullScreenCover(isPresented: $showMessage, onDismiss: { selected = nil }) {
            if let selected { ReadMailView(message: selected) }
        }
    }

    private func open(_ message: MailMessageRecord) { selected = message; showMessage = true }
}

private struct MessageRow: View {
    let message: MailMessageRecord
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(MyrtineTheme.leaf.opacity(0.14)).frame(width: 46, height: 46)
                .overlay { Text(String(message.correspondent.prefix(1)).uppercased()).font(.headline).foregroundStyle(MyrtineTheme.leaf) }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.correspondent).font(.subheadline.weight(message.isRead ? .regular : .bold)).lineLimit(1)
                    Spacer()
                    Text(message.createdAt, format: .dateTime.day().month().hour().minute()).font(.caption2).foregroundStyle(.secondary)
                }
                Text(message.subject.isEmpty ? "(Sans objet)" : message.subject).font(.subheadline.weight(message.isRead ? .regular : .semibold)).lineLimit(1)
                Text(message.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }
}

private struct DeletedFolderView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MailMessageRecord.createdAt, order: .reverse) private var allMessages: [MailMessageRecord]
    let folder: MailFolderRecord

    private var messages: [MailMessageRecord] { allMessages.filter { $0.isDeleted && $0.previousFolderName == folder.name } }

    var body: some View {
        List(messages) { message in MessageRow(message: message) }
            .listStyle(.plain)
            .navigationTitle(folder.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restaurer") { try? environment.store.restoreFolder(folder); dismiss() }.frame(minHeight: 44)
                }
            }
    }
}
