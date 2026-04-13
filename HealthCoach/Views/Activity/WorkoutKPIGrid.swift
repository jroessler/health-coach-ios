import SwiftUI

struct WorkoutKPIGrid: View {
    let kpis: WorkoutKPIs

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            WorkoutKPICard(
                label: "Total Workouts",
                value: "\(kpis.totalWorkouts)",
                subtitle: "Since first log",
                accentColor: .activityNeutral
            )

            WorkoutKPICard(
                label: "Workouts (Last \(kpis.priorDays)d)",
                value: "\(kpis.workoutsLastN)",
                subtitle: deltaLabel(kpis.deltaWorkouts, format: "%.1f", unit: "vs avg"),
                accentColor: kpiColor(kpis.deltaWorkouts, positiveIsGood: true)
            )

            WorkoutKPICard(
                label: "Avg Duration Overall",
                value: "\(Int(kpis.avgDurationOverallMin)) min",
                subtitle: nil,
                accentColor: .activityNeutral
            )

            WorkoutKPICard(
                label: "Avg Duration (Last \(kpis.priorDays)d)",
                value: "\(Int(kpis.avgDurationLastNMin)) min",
                subtitle: deltaLabel(kpis.deltaDurationMin, format: "%.0f", unit: "min vs prior"),
                accentColor: kpiColor(kpis.deltaDurationMin, positiveIsGood: true)
            )
        }
    }

    private func deltaLabel(_ value: Double, format: String, unit: String) -> String {
        let sign = value >= 0 ? "↑" : "↓"
        return "\(sign)\(String(format: format, abs(value))) \(unit)"
    }

    private func kpiColor(_ value: Double, positiveIsGood: Bool) -> Color {
        if positiveIsGood { return value >= 0 ? .activityGood : .activityBad }
        return value <= 0 ? .activityGood : .activityBad
    }
}

// MARK: - Card

private struct WorkoutKPICard: View {
    let label: String
    let value: String
    let subtitle: String?
    let accentColor: Color

    private let cardBg = Color(hex: 0x0A1A24)

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
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

// MARK: - Activity-specific KPI colors

extension Color {
    static let activityGood    = Color(hex: 0x10B981)
    static let activityOk      = Color(hex: 0xFBBF24)
    static let activityBad     = Color(hex: 0xF97316)
    static let activityNeutral = Color(hex: 0x22D3EE)
}
