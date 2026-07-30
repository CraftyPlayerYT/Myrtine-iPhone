import SwiftUI

struct MarkdownDocumentView: View {
    private let blocks: [MarkdownBlock]

    init(markdown: String) { blocks = MarkdownParser.parse(markdown) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            UIApplication.shared.open(url)
            return .handled
        })
    }

    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inline(text).font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                .padding(.top, level == 1 ? 8 : 4)
        case let .paragraph(text): inline(text).font(.body).lineSpacing(4)
        case let .bullet(text):
            HStack(alignment: .firstTextBaseline, spacing: 9) { Text("•").fontWeight(.bold); inline(text).font(.body) }
        case let .numbered(number, text):
            HStack(alignment: .firstTextBaseline, spacing: 8) { Text("\(number).").fontWeight(.semibold).foregroundStyle(MyrtineTheme.accent); inline(text).font(.body) }
        case let .quote(text):
            HStack(alignment: .top, spacing: 10) { Rectangle().fill(MyrtineTheme.accent).frame(width: 3); inline(text).font(.callout).foregroundStyle(.secondary) }
        case let .table(headers, rows): MarkdownTableView(headers: headers, rows: rows)
        case .divider: Divider()
        }
    }

    private func inline(_ markdown: String) -> Text {
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(markdown)
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                tableRow(headers, header: true, shaded: false)
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    tableRow(row, header: false, shaded: rowIndex.isMultiple(of: 2))
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MyrtineTheme.divider) }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.visible)
        .accessibilityIdentifier("diagnostic-result-table")
        .accessibilityLabel("Tableau des aides, \(rows.count) lignes")
    }

    private func tableRow(_ values: [String], header: Bool, shaded: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(headers.indices, id: \.self) { column in
                cell(column < values.count ? values[column] : "", column: column, header: header)
            }
        }
        .background(header ? MyrtineTheme.ink : shaded ? Color.black.opacity(0.035) : Color.white)
        .overlay(alignment: .bottom) { Rectangle().fill(header ? Color.clear : MyrtineTheme.divider).frame(height: 1) }
    }

    private func cell(_ value: String, column: Int, header: Bool) -> some View {
        Group {
            if let attributed = try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributed)
            } else { Text(value) }
        }
        .font(header ? .subheadline.weight(.bold) : .footnote)
        .foregroundStyle(header ? Color.white : MyrtineTheme.ink)
        .lineSpacing(3)
        .frame(width: MarkdownTableLayout.width(for: headers[column]), alignment: .topLeading)
        .frame(minHeight: 52, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .overlay(alignment: .trailing) { Rectangle().fill(header ? Color.white.opacity(0.16) : MyrtineTheme.divider).frame(width: 1) }
    }
}

enum MarkdownTableLayout {
    static func width(for header: String) -> CGFloat {
        let value = header.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if value.contains("critere") { return 300 }
        if value.contains("cahier") || value.contains("lien") { return 240 }
        if value.contains("dispositif") || value.contains("nom") { return 230 }
        if value.contains("fourchette") || value.contains("montant") || value.contains("subvention") { return 200 }
        if value.contains("echeance") || value.contains("date") { return 190 }
        if value.contains("organisme") { return 180 }
        return 210
    }
}

enum MarkdownBlock: Equatable {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case numbered(Int, String)
    case quote(String)
    case table([String], [[String]])
    case divider
}

enum MarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flushParagraph(); index += 1; continue }
            if line.hasPrefix("|") && index + 1 < lines.count && isSeparator(lines[index + 1]) {
                flushParagraph()
                let headers = cells(line)
                index += 2
                var rows: [[String]] = []
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(cells(lines[index]))
                    index += 1
                }
                blocks.append(.table(headers, rows))
                continue
            }
            if line == "---" || line == "***" { flushParagraph(); blocks.append(.divider); index += 1; continue }
            if line.hasPrefix("#") {
                let level = min(line.prefix { $0 == "#" }.count, 6)
                let start = line.index(line.startIndex, offsetBy: level)
                flushParagraph(); blocks.append(.heading(level, line[start...].trimmingCharacters(in: .whitespaces))); index += 1; continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { flushParagraph(); blocks.append(.bullet(String(line.dropFirst(2)))); index += 1; continue }
            if line.hasPrefix("> ") { flushParagraph(); blocks.append(.quote(String(line.dropFirst(2)))); index += 1; continue }
            if let dot = line.firstIndex(of: "."), let number = Int(line[..<dot]), line.index(after: dot) < line.endIndex {
                flushParagraph(); blocks.append(.numbered(number, line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces))); index += 1; continue
            }
            paragraph.append(line)
            index += 1
        }
        flushParagraph()
        return blocks
    }

    private static func cells(_ line: String) -> [String] {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "| ")).split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isSeparator(_ line: String) -> Bool {
        let values = cells(line)
        return !values.isEmpty && values.allSatisfy { $0.replacingOccurrences(of: ":", with: "").allSatisfy { $0 == "-" } }
    }
}
