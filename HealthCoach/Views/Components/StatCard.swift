import SwiftUI

struct StatCard: View {
    let label: String
    let value: String
    let subtitle: String

    private let cardBackground = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)
    private let subtitleColor = Color.white.opacity(0.5)
    private let labelColor = Color.white.opacity(0.7)

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(labelColor)

            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(accentCyan)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
