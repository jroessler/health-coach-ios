import SwiftUI
import MarkdownUI

/// Dark-card styling for nutrition "Additional Information" markdown (GFM tables, lists, emphasis).
enum ChartSectionMarkdownTheme {
    private static let bodyText = Color.white.opacity(0.75)
    private static let strongText = Color.white.opacity(0.95)
    private static let border = Color.white.opacity(0.14)
    private static let tableRowA = Color.clear
    private static let tableRowB = Color.white.opacity(0.05)
    private static let linkColor = Color(hex: 0x22D3EE)

    static var theme: Theme {
        Theme()
            .text {
                FontSize(13)
                ForegroundColor(bodyText)
            }
            .link {
                ForegroundColor(linkColor)
            }
            .strong {
                FontWeight(.semibold)
                ForegroundColor(strongText)
            }
            .paragraph { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.35), bottom: .em(0.35))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.6), bottom: .em(0.35))
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.08))
                        ForegroundColor(strongText)
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.5), bottom: .em(0.3))
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.02))
                        ForegroundColor(strongText)
                    }
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.12))
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.9))
                ForegroundColor(Color.white.opacity(0.88))
                BackgroundColor(Color.white.opacity(0.07))
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: border))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(tableRowA, tableRowB)
                    )
                    .markdownMargin(top: .em(0.4), bottom: .em(0.45))
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        ForegroundColor(bodyText)
                        FontSize(12)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
            }
            .blockquote { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.35), bottom: .em(0.35))
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(linkColor.opacity(0.55))
                            .frame(width: 3)
                    }
            }
    }
}
