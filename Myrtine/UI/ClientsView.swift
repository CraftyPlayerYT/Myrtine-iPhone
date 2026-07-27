import SwiftUI
import SwiftData

struct ClientsView: View {
    @Query(sort: \ClientRecord.lastName) private var clients: [ClientRecord]
    @State private var search = ""

    private var filtered: [ClientRecord] {
        clients.filter { search.isEmpty || [$0.fullName, $0.email, $0.company, $0.phone].contains { $0.localizedCaseInsensitiveContains(search) } }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyStateView(systemImage: "person.2", title: "Aucun client", message: "Les fiches sont créées automatiquement à partir des diagnostics.")
                } else {
                    List(filtered) { client in
                        NavigationLink { ClientDetailView(client: client) } label: {
                            HStack(spacing: 12) {
                                Circle().fill(MyrtineTheme.blueberry.opacity(0.12)).frame(width: 48, height: 48)
                                    .overlay { Text(String(client.firstName.prefix(1)) + String(client.lastName.prefix(1))).font(.headline).foregroundStyle(MyrtineTheme.blueberry) }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(client.fullName.isEmpty ? client.email : client.fullName).font(.body.weight(.semibold)).lineLimit(1)
                                    Text(client.company).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    Text(client.email).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.frame(minHeight: 62)
                        }
                    }.listStyle(.plain)
                }
            }
            .myrtineScreen()
            .navigationTitle("Clients")
            .searchable(text: $search, prompt: "Nom, e-mail, entreprise…")
        }
    }
}

private struct ClientDetailView: View {
    let client: ClientRecord
    @State private var showCompose = false
    @State private var showSMS = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Surface {
                    HStack(spacing: 14) {
                        Circle().fill(MyrtineTheme.blueberry.opacity(0.12)).frame(width: 62, height: 62)
                            .overlay { Text(String(client.firstName.prefix(1)) + String(client.lastName.prefix(1))).font(.title3.weight(.bold)).foregroundStyle(MyrtineTheme.blueberry) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.fullName).font(.title3.weight(.bold))
                            Text(client.company).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 12) {
                    ContactAction(title: "E-mail", systemImage: "envelope", color: MyrtineTheme.accent) { showCompose = true }
                    ContactAction(title: "SMS", systemImage: "message", color: MyrtineTheme.leaf) { showSMS = true }
                    ContactAction(title: "Appeler", systemImage: "phone", color: .orange) {
                        if let url = URL(string: "tel:\(client.phone.filter(\.isNumber))") { UIApplication.shared.open(url) }
                    }
                    .disabled(client.phone.isEmpty)
                }
                Surface {
                    DetailLinePublic(label: "E-mail", value: client.email)
                    DetailLinePublic(label: "Téléphone", value: client.phone)
                    DetailLinePublic(label: "Entreprise", value: client.company)
                    DetailLinePublic(label: "Notes", value: client.notes)
                }
            }.padding(16)
        }
        .myrtineScreen()
        .navigationTitle("Client")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCompose) { ComposeMailView(recipient: client.email) }
        .sheet(isPresented: $showSMS) { MessageComposer(recipients: [client.phone]) }
    }
}

private struct ContactAction: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) { Image(systemName: systemImage).font(.title3); Text(title).font(.caption.weight(.medium)) }
                .foregroundStyle(color).frame(maxWidth: .infinity, minHeight: 72)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(MyrtineTheme.divider) }
        }.buttonStyle(.plain)
    }
}

struct DetailLinePublic: View {
    let label: String
    let value: String
    var body: some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }.padding(.vertical, 6)
        }
    }
}
