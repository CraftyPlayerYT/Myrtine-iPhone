import SwiftUI
import UIKit

struct ColorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initialColor: UIColor
    let allowsClear: Bool
    let onSelect: (UIColor) -> Void
    let onClear: (() -> Void)?

    @State private var color: Color
    @State private var hex: String
    @State private var error = false

    private let presets: [UIColor] = [.label, .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemMint, .systemTeal, .systemCyan, .systemBlue, .systemIndigo, .systemPurple, .systemPink, .systemBrown]

    init(title: String, initialColor: UIColor, allowsClear: Bool = false, onSelect: @escaping (UIColor) -> Void, onClear: (() -> Void)? = nil) {
        self.title = title
        self.initialColor = initialColor
        self.allowsClear = allowsClear
        self.onSelect = onSelect
        self.onClear = onClear
        _color = State(initialValue: Color(uiColor: initialColor))
        _hex = State(initialValue: Self.hex(initialColor))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .frame(height: 132)
                    .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.08)) }

                Text("Couleurs rapides").font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                        Button {
                            color = Color(uiColor: preset)
                            hex = Self.hex(preset)
                        } label: {
                            Circle().fill(Color(uiColor: preset)).frame(width: 44, height: 44)
                                .overlay { Circle().stroke(Color.black.opacity(0.14), lineWidth: 1) }
                        }
                        .accessibilityLabel("Choisir \(Self.hex(preset))")
                    }
                }

                ColorPicker("Sélecteur complet", selection: Binding(
                    get: { color },
                    set: { newValue in color = newValue; hex = Self.hex(UIColor(newValue)) }
                ), supportsOpacity: false)
                    .font(.body.weight(.medium))
                    .frame(minHeight: 50)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Code hexadécimal").font(.subheadline.weight(.medium))
                    TextField("#1A2B3C", text: $hex)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 50)
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(error ? Color.red : MyrtineTheme.divider) }
                        .onSubmit { applyHex() }
                    if error { Text("Utilisez un code comme #FFCC00.").font(.caption).foregroundStyle(.red) }
                }

                Spacer()

                if allowsClear {
                    Button("Retirer la couleur") { onClear?(); dismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Button("Appliquer") {
                    let uiColor = UIColor(hex: hex) ?? UIColor(color)
                    onSelect(uiColor)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .myrtineScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() }.frame(minHeight: 44) } }
        }
    }

    private func applyHex() {
        guard let value = UIColor(hex: hex) else { error = true; return }
        error = false
        color = Color(uiColor: value)
    }

    private static func hex(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "#000000" }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt64(value, radix: 16) else { return nil }
        self.init(red: CGFloat((number & 0xFF0000) >> 16) / 255, green: CGFloat((number & 0x00FF00) >> 8) / 255, blue: CGFloat(number & 0x0000FF) / 255, alpha: 1)
    }
}
