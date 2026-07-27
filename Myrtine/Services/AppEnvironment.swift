import Foundation
import Observation
import SwiftData

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
    var isSyncing = false
    var lastSync: Date?
    var toast: ToastMessage?
    var presentDiagnosticID: String?

    init(inMemory: Bool = false, useMocks: Bool = false) {
        let schema = Schema(MyrtineSchema.types)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible d'initialiser SwiftData: \(error)")
        }

        let localStore = LocalStore(context: container.mainContext)
        let apiClient = MyrtineAPIClient(network: network, store: localStore, useMocks: useMocks)
        let supabaseClient = SupabaseSyncClient(network: network, store: localStore, useMocks: useMocks)
        store = localStore
        api = apiClient
        supabase = supabaseClient
        sync = SyncCoordinator(network: network, store: localStore, api: apiClient, supabase: supabaseClient)
    }

    func start() async {
        store.seedSystemFolders()
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            store.seedPreviewData()
        }
        if ProcessInfo.processInfo.arguments.contains("-network-offline") {
            network.simulation = .offline
        }
        await synchronize()
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
}
