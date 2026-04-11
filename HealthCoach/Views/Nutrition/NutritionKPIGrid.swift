import SwiftUI

struct NutritionKPIGrid: View {
    let kpis: NutritionKPIs

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            KPICard(
                label: "Last 7d avg kcal",
                value: "\(Int(kpis.last7dAvgKcal))",
                accentColor: .kpiNeutral
            )
            KPICard(
                label: "Total Body Fat Loss",
                value: formatOptional(kpis.totalBodyFatChange, suffix: "%", decimals: 1),
                accentColor: colorForDelta(kpis.totalBodyFatChange)
            )
            KPICard(
                label: "Total Weight Loss",
                value: formatOptional(kpis.totalWeightChange, suffix: "kg", decimals: 1),
                accentColor: colorForDelta(kpis.totalWeightChange)
            )
            KPICard(
                label: "7d avg Protein/kg",
                value: String(format: "%.2fg/kg", kpis.sevenDayProteinPerKg),
                accentColor: proteinColor(kpis.sevenDayProteinPerKg)
            )
        }
    }

    private func formatOptional(_ value: Double?, suffix: String, decimals: Int) -> String {
        guard let v = value else { return "--" }
        return String(format: "%.\(decimals)f", v) + suffix
    }

    private func colorForDelta(_ value: Double?) -> Color {
        guard let v = value else { return .kpiNeutral }
        return v < 0 ? .kpiGood : .kpiBad
    }

    private func proteinColor(_ value: Double) -> Color {
        if value >= 1.8 { return .kpiGood }
        if value >= 1.4 { return .kpiBad }
        return .kpiBad
    }
}

// MARK: - KPI Card

private struct KPICard: View {
    let label: String
    let value: String
    let accentColor: Color

    private let cardBg = Color(hex: 0x0A1A24)

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)

                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - KPI Colors (mirrors globals.py KPI_FONT_COLOR_*)

extension Color {
    static let kpiGood = Color(hex: 0x10B981)
    static let kpiNeutral = Color(hex: 0x10B981)
    static let kpiOk = Color(hex: 0xFBBF24)
    static let kpiBad = Color(hex: 0xF97316)
}
