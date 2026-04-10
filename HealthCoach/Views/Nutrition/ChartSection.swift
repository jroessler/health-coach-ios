import SwiftUI
import MarkdownUI

struct ChartSection<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content

    @State private var showDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)

            DisclosureGroup(isExpanded: $showDescription) {
                Markdown(description)
                    .markdownTheme(ChartSectionMarkdownTheme.theme)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text("Additional Information")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: 0x22D3EE))
            }
            .tint(Color(hex: 0x22D3EE))

            content()
        }
        .padding(16)
        .background(Color(hex: 0x0A1A24))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
