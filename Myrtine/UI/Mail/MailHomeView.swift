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
    @State private var notificationMessage: MailMessageRecord?
    @State private var navigationPath: [String] = []
    @State private var restoredLastFolder = false
    @AppStorage("mail.last.folder") private var lastFolderName = ""

    private var folders: [MailFolderRecord] { allFolders.filter { !$0.isTrashed }.sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section("contact@myrtine.fr") {
                    ForEach(folders) { folder in
                        NavigationLink(value: folder.name) {
                            FolderRow(folder: folder, count: messageCount(folder), unread: unreadCount(folder))
                        }
                        .accessibilityIdentifier("mail-folder-\(folder.kind)")
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
            .navigationDestination(for: String.self) { folderName in
                if let folder = allFolders.first(where: { $0.name == folderName && !$0.isTrashed }) {
                    MailFolderView(folder: folder)
                        .onAppear { lastFolderName = folder.name }
                } else {
                    EmptyStateView(systemImage: "folder.badge.questionmark", title: "Dossier indisponible", message: "Ce dossier n’existe plus.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.tint(MyrtineTheme.accent.opacity(0.16)).interactive(), in: .circle)
                    .accessibilityLabel("Nouveau message")
                    .accessibilityIdentifier("mail-compose")
                }
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
            .fullScreenCover(item: $notificationMessage) { message in ReadMailView(message: message) }
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
            .onAppear {
                guard !restoredLastFolder else { return }
                restoredLastFolder = true
                if folders.contains(where: { $0.name == lastFolderName }) { navigationPath = [lastFolderName] }
                if let id = environment.presentMessageID { Task { await openNotificationMessage(id) } }
            }
            .onChange(of: environment.presentMessageID) { _, id in
                if let id { Task { await openNotificationMessage(id) } }
            }
        }
    }

    private func messageCount(_ folder: MailFolderRecord) -> Int {
        allMessages.filter { messageBelongs($0, to: folder) }.count
    }

    private func unreadCount(_ folder: MailFolderRecord) -> Int {
        allMessages.filter { messageBelongs($0, to: folder) && !$0.isRead }.count
    }

    private func messageBelongs(_ message: MailMessageRecord, to folder: MailFolderRecord) -> Bool {
        return switch folder.kind {
        case "trash": message.isTrashed
        case "inbox": !message.isTrashed && message.direction == "received"
        case "sent": !message.isTrashed && message.direction == "sent"
        case "custom": !message.isTrashed && (message.folderName.caseInsensitiveCompare(folder.name) == .orderedSame || message.correspondent.caseInsensitiveCompare(folder.name) == .orderedSame)
        default: !message.isTrashed && message.folderName.caseInsensitiveCompare(folder.name) == .orderedSame
        }
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

    private func openNotificationMessage(_ id: String) async {
        if let message = allMessages.first(where: { $0.id == id }) {
            environment.presentMessageID = nil
            notificationMessage = message
            return
        }
        await environment.synchronize()
        if let message = allMessages.first(where: { $0.id == id }) {
            environment.presentMessageID = nil
            notificationMessage = message
        } else {
            environment.toast = ToastMessage(title: "Message introuvable", message: "Il n’a pas encore été synchronisé.", kind: .warning)
        }
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
    }
}

struct MailFolderView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \MailMessageRecord.createdAt, order: .reverse) private var allMessages: [MailMessageRecord]
    @Query(sort: \MailFolderRecord.updatedAt, order: .reverse) private var allFolders: [MailFolderRecord]
    let folder: MailFolderRecord
    @State private var search = ""
    @State private var selected: MailMessageRecord?
    @State private var showCompose = false

    private var messages: [MailMessageRecord] {
        allMessages.filter { message in
            let belongs = switch folder.kind {
            case "trash": message.isTrashed
            case "inbox": !message.isTrashed && message.direction == "received"
            case "sent": !message.isTrashed && message.direction == "sent"
            case "custom": !message.isTrashed && (message.folderName.caseInsensitiveCompare(folder.name) == .orderedSame || message.correspondent.caseInsensitiveCompare(folder.name) == .orderedSame)
            default: !message.isTrashed && message.folderName.caseInsensitiveCompare(folder.name) == .orderedSame
            }
            return belongs && (search.isEmpty || [message.correspondent, message.subject, message.body].contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }
    private var deletedFolders: [MailFolderRecord] { folder.kind == "trash" ? allFolders.filter { $0.isTrashed } : [] }

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
                                MessageRow(message: message)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture { open(message) }
                                Menu {
                                    Button { open(message) } label: { Label("Ouvrir", systemImage: "envelope.open") }
                                    if message.isTrashed {
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
            if folder.kind != "trash" {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }.frame(minWidth: 44, minHeight: 44).accessibilityLabel("Nouveau message")
                }
            }
        }
        .fullScreenCover(isPresented: $showCompose) { ComposeMailView() }
        .fullScreenCover(item: $selected) { message in
            ReadMailView(message: message)
        }
    }

    private func open(_ message: MailMessageRecord) { selected = message }
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
    @State private var selected: MailMessageRecord?

    private var messages: [MailMessageRecord] { allMessages.filter { $0.isTrashed && $0.previousFolderName == folder.name } }

    var body: some View {
        List(messages) { message in
            MessageRow(message: message)
                .contentShape(Rectangle())
                .onTapGesture { selected = message }
        }
            .listStyle(.plain)
            .navigationTitle(folder.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restaurer") { try? environment.store.restoreFolder(folder); dismiss() }.frame(minHeight: 44)
                }
            }
            .fullScreenCover(item: $selected) { message in ReadMailView(message: message) }
    }
}
