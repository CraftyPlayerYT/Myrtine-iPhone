import SwiftUI
import SwiftData

struct CommunicationsView: View {
    @Query(sort: \ClientRecord.lastName) private var clients: [ClientRecord]
    @State private var search = ""
    @State private var smsClient: ClientRecord?

    private var filtered: [ClientRecord] { clients.filter { !$0.phone.isEmpty && (search.isEmpty || $0.fullName.localizedCaseInsensitiveContains(search) || $0.phone.contains(search)) } }

    var body: some View {
        Group {
            if filtered.isEmpty { EmptyStateView(systemImage: "phone.bubble", title: "Aucun numéro", message: "Ajoutez un téléphone à une fiche client pour appeler ou envoyer un SMS.") }
            else {
                List(filtered) { client in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text(client.fullName).font(.body.weight(.semibold)); Text(client.phone).font(.subheadline).foregroundStyle(.secondary) }
                        Spacer()
                        Button { smsClient = client } label: { Image(systemName: "message").frame(width: 44, height: 44) }.accessibilityLabel("Envoyer un SMS à \(client.fullName)")
                        Button { if let url = URL(string: "tel:\(client.phone.filter(\.isNumber))") { UIApplication.shared.open(url) } } label: { Image(systemName: "phone").frame(width: 44, height: 44) }.accessibilityLabel("Appeler \(client.fullName)")
                    }.frame(minHeight: 58)
                }.listStyle(.plain)
            }
        }
        .myrtineScreen().navigationTitle("Appels et SMS").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Rechercher un client")
        .sheet(item: $smsClient) { client in MessageComposer(recipients: [client.phone]) }
    }
}
