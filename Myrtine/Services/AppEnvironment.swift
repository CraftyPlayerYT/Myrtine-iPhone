import Foundation
import Observation
import SwiftData
import UIKit
import UserNotifications

@MainActor
@Observable
final class AppEnvironment {
    enum SelectedTab: Hashable { case home, diagnostics, mail, clients, more }

    let container: ModelContainer
    let network = NetworkMonitor()
    let store: LocalStore
    let api: MyrtineAPIClient
    let supabase: SupabaseSyncClient
    let sync: SyncCoordinator

    var selectedTab: SelectedTab = .home
    var isActivated: Bool
    var isLocalDataReady = false
    var isSyncing = false
    var lastSync: Date?
    var toast: ToastMessage?
    var presentDiagnosticID: String?
    var presentMessageID: String?
    @ObservationIgnored private var notificationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var startupSyncTask: Task<Void, Never>?
    @ObservationIgnored private var notificationsConfigured = false

    init(inMemory: Bool = false, useMocks: Bool = false) {
        let schema = Schema(MyrtineSchema.types)
        var storageWarning: String?
        if !inMemory {
            do { try LocalDataSecurity.prepareProtectedStorage() }
            catch { storageWarning = error.localizedDescription }
        }
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let resolvedContainer: ModelContainer
        do {
            resolvedContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            storageWarning = error.localizedDescription
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                resolvedContainer = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                preconditionFailure("Impossible d'initialiser le stockage local: \(error)")
            }
        }
        container = resolvedContainer
        if !inMemory {
            do { try LocalDataSecurity.sealExistingStoreFiles() }
            catch { storageWarning = storageWarning ?? error.localizedDescription }
        }

        let localStore = LocalStore(context: container.mainContext)
        let apiClient = MyrtineAPIClient(network: network, store: localStore, useMocks: useMocks)
        let supabaseClient = SupabaseSyncClient(network: network, store: localStore, api: apiClient, useMocks: useMocks)
        store = localStore
        api = apiClient
        supabase = supabaseClient
        sync = SyncCoordinator(network: network, store: localStore, api: apiClient, supabase: supabaseClient)
        isActivated = apiClient.isActivated && !ProcessInfo.processInfo.arguments.contains("-force-activation")
        if let storageWarning {
            localStore.log(level: "Erreur", category: "Stockage", message: "Cache local ouvert en mode de secours", detail: storageWarning)
        }
    }

    func start() async {
        store.seedSystemFolders()
        isLocalDataReady = true
        configureNotificationObservers()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            UserDefaults.standard.removeObject(forKey: "mail.last.folder")
        }
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            store.seedPreviewData()
        }
        if ProcessInfo.processInfo.arguments.contains("-network-offline") {
            network.simulation = .offline
        }
        if isActivated {
            let pending = PushNotificationBridge.takePending()
            startupSyncTask?.cancel()
            startupSyncTask = Task { [weak self] in
                guard let self else { return }
                await Task.yield()
                await self.requestNotificationPermission()
                if let pending { await self.handlePush(pending) }
                else { await self.synchronize() }
            }
        }
    }

    func protectLocalData() {
        do { try LocalDataSecurity.sealExistingStoreFiles() }
        catch {
            store.log(level: "Avertissement", category: "Stockage", message: "Protection du cache local incomplète", detail: error.localizedDescription)
        }
    }

    func activate(code: String) async throws {
        try await api.activate(code: code, deviceName: "iPhone")
        isActivated = true
        toast = ToastMessage(title: "iPhone activé", message: "Les services Myrtine sont maintenant disponibles.", kind: .success)
        await requestNotificationPermission()
        await synchronize()
    }

    func open(_ destination: AppDestination) {
        switch destination {
        case let .diagnostic(id):
            selectedTab = .diagnostics
            presentDiagnosticID = id
        case let .message(id):
            selectedTab = .mail
            presentMessageID = id
        }
    }

    private func configureNotificationObservers() {
        guard !notificationsConfigured else { return }
        notificationsConfigured = true
        notificationTasks.append(Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .myrtinePush) {
                guard let kind = notification.userInfo?["kind"] as? String,
                      let id = notification.userInfo?["id"] as? String else { continue }
                let payload = ["kind": kind, "id": id, "open": notification.userInfo?["open"] as? String ?? "false"]
                await self?.handlePush(payload)
            }
        })
        notificationTasks.append(Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .myrtineAPNSToken) {
                guard let token = notification.object as? String else { continue }
                do {
                    #if DEBUG
                    let apnsEnvironment = "sandbox"
                    #else
                    let apnsEnvironment = "production"
                    #endif
                    try await self?.api.registerPushToken(token, environment: apnsEnvironment)
                } catch {
                    self?.store.log(level: "Avertissement", category: "Notifications", message: "Jeton APNs non enregistré", detail: error.localizedDescription)
                }
            }
        })
        notificationTasks.append(Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .myrtineAPNSError) {
                self?.store.log(level: "Avertissement", category: "Notifications", message: "APNs indisponible", detail: notification.object as? String ?? "Erreur inconnue")
            }
        })
    }

    private func requestNotificationPermission() async {
        guard !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        } catch {
            store.log(level: "Avertissement", category: "Notifications", message: "Autorisation de notification refusée", detail: error.localizedDescription)
        }
    }

    private func handlePush(_ payload: [String: String]) async {
        guard let kind = payload["kind"], let id = payload["id"] else { return }
        await synchronize()
        let destination: AppDestination = kind == "diagnostic" ? .diagnostic(id) : .message(id)
        if payload["open"] == "true" {
            open(destination)
        } else {
            toast = ToastMessage(
                title: kind == "diagnostic" ? "Nouveau diagnostic" : "Nouveau message",
                message: "Touchez pour l’ouvrir.",
                kind: .information,
                destination: destination
            )
        }
    }

    func synchronize() async {
        guard network.isOnline, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await sync.synchronize()
            lastSync = .now
        } catch {
            store.log(level: "Avertissement", category: "Synchronisation", message: "Synchronisation incomplète", detail: error.localizedDescription)
            toast = ToastMessage(title: "Synchronisation interrompue", message: error.localizedDescription, kind: .warning)
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    enum Kind: Equatable { case information, success, warning, error }
    let id = UUID()
    let title: String
    let message: String
    let kind: Kind
    var destination: AppDestination? = nil
}

enum AppDestination: Equatable {
    case diagnostic(String)
    case message(String)
}
