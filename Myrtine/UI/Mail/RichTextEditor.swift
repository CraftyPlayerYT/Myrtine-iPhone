import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
final class RichTextEditorController {
    @ObservationIgnored weak var textView: UITextView?
    var attributedText = NSAttributedString(string: "", attributes: RichTextEditorController.defaultAttributes)
    var selection = NSRange(location: 0, length: 0)
    var inlineAttachments: [MailAttachmentPayload] = []
    var regularAttachments: [MailAttachmentPayload] = []
    var textColor = UIColor.label
    var highlightColor = UIColor.yellow
    var fontSize: CGFloat = 17
    var formattingRevision = 0

    static let defaultAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.preferredFont(forTextStyle: .body),
        .foregroundColor: UIColor.label
    ]

    var plainText: String { attributedText.string }

    var isBold: Bool { _ = formattingRevision; return currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) }
    var isItalic: Bool { _ = formattingRevision; return currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) }
    var isUnderlined: Bool { _ = formattingRevision; return ((currentAttributes[.underlineStyle] as? Int) ?? 0) != 0 }

    private var currentAttributes: [NSAttributedString.Key: Any] {
        guard let view = textView else { return Self.defaultAttributes }
        if view.selectedRange.length == 0 { return view.typingAttributes }
        let location = min(view.selectedRange.location, max(view.textStorage.length - 1, 0))
        return view.textStorage.length > 0 ? view.textStorage.attributes(at: location, effectiveRange: nil) : view.typingAttributes
    }

    private var currentFont: UIFont {
        (currentAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: fontSize)
    }

    func load(html: String, fallback: String = "") {
        guard !html.isEmpty, let data = html.data(using: .utf8),
              let value = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) else {
            attributedText = NSAttributedString(string: fallback, attributes: Self.defaultAttributes)
            return
        }
        attributedText = value
    }

    func toggleBold() { toggleTrait(.traitBold) }
    func toggleItalic() { toggleTrait(.traitItalic) }

    func toggleUnderline() {
        applyAttribute(.underlineStyle) { current in
            let active = (current as? Int ?? 0) != 0
            return active ? 0 : NSUnderlineStyle.single.rawValue
        }
    }

    func applyTextColor(_ color: UIColor) {
        textColor = color
        applyAttribute(.foregroundColor) { _ in color }
    }

    func applyHighlight(_ color: UIColor) {
        highlightColor = color
        applyAttribute(.backgroundColor) { _ in color }
    }

    func clearHighlight() { applyAttribute(.backgroundColor) { _ in UIColor.clear } }

    func applyFontSize(_ size: CGFloat) {
        fontSize = size
        applyAttribute(.font) { current in
            let font = (current as? UIFont) ?? UIFont.systemFont(ofSize: size)
            return font.withSize(size)
        }
    }

    func insertLink(_ rawURL: String) throws {
        guard let url = URL(string: rawURL), let view = textView else { throw EditorError.invalidURL }
        let range = view.selectedRange
        guard range.length > 0 else { throw EditorError.selectionRequired }
        view.textStorage.addAttributes([.link: url, .foregroundColor: UIColor.systemBlue, .underlineStyle: NSUnderlineStyle.single.rawValue], range: range)
        synchronize(from: view)
    }

    func insertImage(data: Data, fileName: String, contentType: String) throws {
        guard ImageValidator.isAllowed(data: data, fileName: fileName, contentType: contentType) else { throw EditorError.invalidImage }
        guard let view = textView else { throw EditorError.editorUnavailable }
        let contentID = UUID().uuidString.lowercased()
        let attachment = NSTextAttachment(data: data, ofType: contentType)
        attachment.fileWrapper?.preferredFilename = fileName
        if let image = UIImage(data: data) {
            let maxWidth = min(view.bounds.width - 32, 520)
            let ratio = maxWidth / max(image.size.width, 1)
            let width = min(image.size.width, maxWidth)
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -4, width: width, height: image.size.height * min(ratio, 1))
        }
        let value = NSMutableAttributedString(attachment: attachment)
        value.append(NSAttributedString(string: "\n", attributes: Self.defaultAttributes))
        view.textStorage.replaceCharacters(in: view.selectedRange, with: value)
        view.selectedRange = NSRange(location: min(view.selectedRange.location + value.length, view.textStorage.length), length: 0)
        inlineAttachments.append(MailAttachmentPayload(fileName: fileName, contentType: contentType, base64Content: data.base64EncodedString(), isInline: true, contentID: contentID))
        synchronize(from: view)
    }

    func addDocument(data: Data, fileName: String, contentType: String) {
        regularAttachments.removeAll { $0.fileName == fileName }
        regularAttachments.append(MailAttachmentPayload(fileName: fileName, contentType: contentType, base64Content: data.base64EncodedString(), isInline: false, contentID: nil))
    }

    func removeAttachment(_ attachment: MailAttachmentPayload) {
        regularAttachments.removeAll { $0.id == attachment.id }
    }

    func synchronize(from view: UITextView) {
        attributedText = view.attributedText.copy() as? NSAttributedString ?? NSAttributedString(string: view.text)
        selection = view.selectedRange
    }

    func htmlDocument() -> String {
        RichTextHTMLSerializer.serialize(attributedText, inlineAttachments: inlineAttachments)
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let view = textView else { return }
        let range = view.selectedRange
        let baseFont = (view.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: fontSize)
        let active = baseFont.fontDescriptor.symbolicTraits.contains(trait)
        if range.length == 0 {
            var traits = baseFont.fontDescriptor.symbolicTraits
            if active { traits.remove(trait) } else { traits.insert(trait) }
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                view.typingAttributes[.font] = UIFont(descriptor: descriptor, size: baseFont.pointSize)
            }
            formattingRevision += 1
            return
        }
        view.textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? UIFont) ?? baseFont
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                view.textStorage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: subrange)
            }
        }
        synchronize(from: view)
        formattingRevision += 1
    }

    private func applyAttribute(_ key: NSAttributedString.Key, transform: (Any?) -> Any) {
        guard let view = textView else { return }
        let range = view.selectedRange
        if range.length == 0 {
            view.typingAttributes[key] = transform(view.typingAttributes[key])
        } else {
            view.textStorage.enumerateAttribute(key, in: range) { value, subrange, _ in
                view.textStorage.addAttribute(key, value: transform(value), range: subrange)
            }
            synchronize(from: view)
        }
        formattingRevision += 1
    }

    enum EditorError: LocalizedError {
        case invalidURL, selectionRequired, invalidImage, editorUnavailable
        var errorDescription: String? {
            switch self {
            case .invalidURL: "Le lien est invalide."
            case .selectionRequired: "Sélectionnez d'abord le texte qui doit devenir un lien."
            case .invalidImage: "Image refusée. Formats autorisés : SVG, JPEG, JPG, WEBP et PNG."
            case .editorUnavailable: "L'éditeur n'est pas encore prêt."
            }
        }
    }
}

struct RichTextEditor: UIViewRepresentable {
    let controller: RichTextEditorController
    var isEditable = true

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: true)
        view.delegate = context.coordinator
        view.attributedText = controller.attributedText
        view.typingAttributes = RichTextEditorController.defaultAttributes
        view.backgroundColor = .clear
        view.isEditable = isEditable
        view.isSelectable = true
        view.allowsEditingTextAttributes = true
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 20, right: 12)
        view.accessibilityIdentifier = isEditable ? "rich-text-editor" : "rich-text-reader"
        controller.textView = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.isEditable = isEditable
        if !view.isFirstResponder && !view.attributedText.isEqual(to: controller.attributedText) {
            view.attributedText = controller.attributedText
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let controller: RichTextEditorController
        init(controller: RichTextEditorController) { self.controller = controller }
        func textViewDidChange(_ textView: UITextView) { controller.synchronize(from: textView) }
        func textViewDidChangeSelection(_ textView: UITextView) {
            controller.selection = textView.selectedRange
            controller.formattingRevision += 1
        }
    }
}

enum ImageValidator {
    private static let allowedExtensions = Set(["svg", "jpeg", "jpg", "webp", "png"])
    private static let allowedTypes = Set(["image/svg+xml", "image/jpeg", "image/webp", "image/png"])

    static func isAllowed(data: Data, fileName: String, contentType: String) -> Bool {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        guard allowedExtensions.contains(ext), allowedTypes.contains(contentType.lowercased()), !data.isEmpty, data.count <= 12_000_000 else { return false }
        let bytes = [UInt8](data.prefix(12))
        switch ext {
        case "png": return bytes.starts(with: [0x89, 0x50, 0x4E, 0x47])
        case "jpg", "jpeg": return bytes.starts(with: [0xFF, 0xD8, 0xFF])
        case "webp": return data.count >= 12 && String(data: data.prefix(4), encoding: .ascii) == "RIFF" && String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP"
        case "svg":
            let prefix = String(data: data.prefix(4096), encoding: .utf8)?.lowercased() ?? ""
            return prefix.contains("<svg") && !prefix.contains("<script")
        default: return false
        }
    }
}

enum RichTextHTMLSerializer {
    static func serialize(_ value: NSAttributedString, inlineAttachments: [MailAttachmentPayload]) -> String {
        var body = ""
        var attachmentIndex = 0
        let fullRange = NSRange(location: 0, length: value.length)
        value.enumerateAttributes(in: fullRange) { attributes, range, _ in
            if attributes[.attachment] is NSTextAttachment {
                if attachmentIndex < inlineAttachments.count, let cid = inlineAttachments[attachmentIndex].contentID {
                    let name = escape(inlineAttachments[attachmentIndex].fileName)
                    body += "<img src=\"cid:\(cid)\" alt=\"\(name)\" style=\"max-width:100%;height:auto;display:block;margin:12px 0\">"
                }
                attachmentIndex += 1
                return
            }
            var text = escape(value.attributedSubstring(from: range).string).replacingOccurrences(of: "\n", with: "<br>")
            if let link = attributes[.link] as? URL { text = "<a href=\"\(escape(link.absoluteString))\">\(text)</a>" }
            if let color = attributes[.foregroundColor] as? UIColor { text = "<span style=\"color:\(hex(color))\">\(text)</span>" }
            if let color = attributes[.backgroundColor] as? UIColor, color.cgColor.alpha > 0.01 { text = "<span style=\"background-color:\(hex(color))\">\(text)</span>" }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { text = "<u>\(text)</u>" }
            if let font = attributes[.font] as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { text = "<em>\(text)</em>" }
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { text = "<strong>\(text)</strong>" }
                text = "<span style=\"font-size:\(Int(font.pointSize))px\">\(text)</span>"
            }
            body += text
        }
        return "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"></head><body style=\"font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;font-size:17px;line-height:1.55;color:#171B2E\">\(body)</body></html>"
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func hex(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "#000000" }
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
