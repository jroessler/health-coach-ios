import SwiftUI

struct MacroTargetBars: View {
    let data: MacroTargetData
    let preferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TARGET DISTRIBUTION")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(2)

            macroBar(
                name: "Protein",
                color: Color(hex: 0x1F77B4),
                actual: data.avgProteinPct,
                target: Double(preferences.targetProteinPct)
            )
            macroBar(
                name: "Carbs",
                color: Color(hex: 0x2CA02C),
                actual: data.avgCarbsPct,
                target: Double(preferences.targetCarbsPct)
            )
            macroBar(
                name: "Fat",
                color: Color(hex: 0xFF7F0E),
                actual: data.avgFatPct,
                target: Double(preferences.targetFatPct)
            )
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x22D3EE, opacity: 0.05), Color(hex: 0x06B6D4, opacity: 0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: 0x22D3EE, opacity: 0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func macroBar(name: String, color: Color, actual: Double?, target: Double) -> some View {
        let actualVal = actual ?? 0
        let displayStr = actual.map { String(format: "%.1f", $0) + "%" } ?? "--"
        let barColor = pctColor(actualVal, target: target)
        let fillPct = target > 0 ? min(actualVal / target, 1.0) : 0

        VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                Spacer()
                Text(displayStr)
                    .font(.callout.weight(.heavy))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * fillPct, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("0%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Target: \(Int(target))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    /// Mirrors pct_color() in 1_Nutrition.py: within 10% relative = good, within 20% = ok, else bad.
    private func pctColor(_ actual: Double, target: Double, tolerance: Double = 10) -> Color {
        guard target > 0 else { return .kpiNeutral }
        let diff = abs(actual - target) / target * 100
        if diff <= tolerance { return .kpiGood }
        if diff <= tolerance * 2 { return .kpiOk }
        return .kpiBad
    }
}
