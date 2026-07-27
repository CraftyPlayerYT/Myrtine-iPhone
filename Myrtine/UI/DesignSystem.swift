import SwiftUI

enum MyrtineTheme {
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.24)
    static let blueberry = Color(red: 0.22, green: 0.10, blue: 0.34)
    static let leaf = Color(red: 0.19, green: 0.48, blue: 0.24)
    static let accent = Color(red: 0.22, green: 0.35, blue: 0.78)
    static let canvas = Color(red: 0.965, green: 0.975, blue: 0.985)
    static let surface = Color.white
    static let divider = Color.black.opacity(0.08)
}

struct Surface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MyrtineTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MyrtineTheme.divider)
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .glassEffect(.regular.tint(MyrtineTheme.accent.opacity(configuration.isPressed ? 0.78 : 1)).interactive(), in: .rect(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(MyrtineTheme.ink)
            .frame(minHeight: 46)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(configuration.isPressed ? 0.66 : 0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MyrtineTheme.divider) }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .symbolRenderingMode(.hierarchical)
    }
}

struct StatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
            .accessibilityLabel("État : \(title)")
    }
}

extension View {
    func myrtineScreen() -> some View {
        self
            .background(MyrtineTheme.canvas.ignoresSafeArea())
            .tint(MyrtineTheme.accent)
    }
}
