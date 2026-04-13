import SwiftUI

// Block-level markdown renderer for AI Coach summaries.
// Handles the Claude output format: ## headers, ### sub-headers, - bullets,
// | tables |, and inline bold/italic/code via AttributedString.

struct CoachMarkdownView: View {

    let markdown: String

    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - Block rendering

    @ViewBuilder
    private func blockView(_ block: MDBlock) -> some View {
        switch block {
        case .h2(let text):
            inlineText(text)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.top, 20)
                .padding(.bottom, 4)

        case .h3(let text):
            inlineText(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(accentCyan)
                .padding(.top, 12)
                .padding(.bottom, 2)

        case .h4(let text):
            inlineText(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 8)
                .padding(.bottom, 2)

        case .bullet(let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(indent > 0 ? "›" : "•")
                    .foregroundStyle(indent > 0 ? .secondary : accentCyan)
                    .font(.callout)
                inlineText(text)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(indent) * 16)
            .padding(.vertical, 2)

        case .table(let rows):
            tableView(rows)
                .padding(.vertical, 6)

        case .paragraph(let text):
            inlineText(text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.vertical, 3)

        case .divider:
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 8)

        case .spacer:
            Color.clear.frame(height: 4)
        }
    }

    // Renders inline markdown (bold, italic, code) via AttributedString
    private func inlineText(_ raw: String) -> Text {
        if let attr = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(raw)
    }

    // MARK: - Table rendering

    private func tableView(_ rows: [[String]]) -> some View {
        let headerRow = rows.first ?? []
        let bodyRows = rows.dropFirst().filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .init(charactersIn: "-: ")).isEmpty }
        }

        return VStack(alignment: .leading, spacing: 0) {
            if !headerRow.isEmpty {
                tableRowView(headerRow, isHeader: true)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }
            ForEach(Array(bodyRows.enumerated()), id: \.offset) { idx, row in
                tableRowView(row, isHeader: false)
                    .background(idx % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func tableRowView(_ cells: [String], isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                let trimmed = cell.trimmingCharacters(in: .whitespaces)
                if let attr = try? AttributedString(
                    markdown: trimmed,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attr)
                        .font(isHeader ? .caption.weight(.semibold) : .caption)
                        .foregroundStyle(isHeader ? accentCyan : .white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                } else {
                    Text(trimmed)
                        .font(isHeader ? .caption.weight(.semibold) : .caption)
                        .foregroundStyle(isHeader ? accentCyan : .white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Markdown parser

    private var blocks: [MDBlock] {
        var result: [MDBlock] = []
        var tableRows: [[String]] = []

        func flushTable() {
            if !tableRows.isEmpty {
                result.append(.table(tableRows))
                tableRows = []
            }
        }

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Table row
            if trimmed.hasPrefix("|") {
                let cells = trimmed
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty || tableRows.isEmpty }
                if cells.isEmpty && tableRows.isEmpty { continue }
                tableRows.append(cells)
                continue
            } else {
                flushTable()
            }

            // Heading
            if trimmed.hasPrefix("#### ") {
                result.append(.h4(String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix("### ") {
                result.append(.h3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                result.append(.h2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                result.append(.h2(String(trimmed.dropFirst(2))))

            // Horizontal rule
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.divider)

            // Indented bullet
            } else if line.hasPrefix("    - ") || line.hasPrefix("    * ") || line.hasPrefix("  - ") || line.hasPrefix("  * ") {
                let indent = line.hasPrefix("    ") ? 2 : 1
                let stripped = trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2))
                             : trimmed.hasPrefix("* ") ? String(trimmed.dropFirst(2))
                             : trimmed
                result.append(.bullet(stripped, indent: indent))

            // Top-level bullet
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let stripped = trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2))
                             : String(trimmed.dropFirst(2))
                result.append(.bullet(stripped, indent: 0))

            // Numbered list (treat as bullet)
            } else if trimmed.first?.isNumber == true,
                      let dotIdx = trimmed.firstIndex(of: "."),
                      trimmed.index(after: dotIdx) < trimmed.endIndex,
                      trimmed[trimmed.index(after: dotIdx)] == " " {
                let text = String(trimmed[trimmed.index(dotIdx, offsetBy: 2)...])
                result.append(.bullet(text, indent: 0))

            // Empty line → spacer
            } else if trimmed.isEmpty {
                if result.last.map({ if case .spacer = $0 { return true }; return false }) != true {
                    result.append(.spacer)
                }

            // Regular paragraph
            } else {
                result.append(.paragraph(trimmed))
            }
        }

        flushTable()
        return result
    }
}

// MARK: - Block types

private enum MDBlock {
    case h2(String)
    case h3(String)
    case h4(String)
    case bullet(String, indent: Int)
    case table([[String]])
    case paragraph(String)
    case divider
    case spacer
}
