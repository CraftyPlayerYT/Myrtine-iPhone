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
    private let width: CGFloat = 190

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        cell(header, header: true)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(headers.indices, id: \.self) { column in
                            cell(column < row.count ? row[column] : "", header: false)
                                .background(rowIndex.isMultiple(of: 2) ? Color.black.opacity(0.025) : .clear)
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MyrtineTheme.divider) }
        }
        .scrollIndicators(.visible)
        .accessibilityLabel("Tableau des aides, \(rows.count) lignes")
    }

    private func cell(_ value: String, header: Bool) -> some View {
        Group {
            if let attributed = try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributed)
            } else { Text(value) }
        }
        .font(header ? .subheadline.weight(.bold) : .footnote)
        .foregroundStyle(header ? Color.white : MyrtineTheme.ink)
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: 48, alignment: .topLeading)
        .padding(10)
        .background(header ? MyrtineTheme.ink : .clear)
        .overlay(alignment: .trailing) { Rectangle().fill(header ? Color.white.opacity(0.16) : MyrtineTheme.divider).frame(width: 1) }
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
