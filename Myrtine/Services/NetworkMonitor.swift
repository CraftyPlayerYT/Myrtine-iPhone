import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkMonitor {
    enum Simulation: String, CaseIterable, Identifiable {
        case automatic = "Réseau réel"
        case online = "Forcer en ligne"
        case offline = "Forcer hors ligne"

        var id: String { rawValue }
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "fr.myrtine.network-monitor", qos: .utility)
    private var measuredOnline = true
    var simulation: Simulation = .automatic
    var interfaceName = "Indéterminé"

    var isOnline: Bool {
        switch simulation {
        case .automatic: measuredOnline
        case .online: true
        case .offline: false
        }
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.measuredOnline = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self.interfaceName = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self.interfaceName = "Réseau mobile"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.interfaceName = "Ethernet"
                } else {
                    self.interfaceName = self.measuredOnline ? "Autre" : "Hors ligne"
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
