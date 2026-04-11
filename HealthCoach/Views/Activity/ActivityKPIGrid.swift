import SwiftUI

struct ActivityKPIGrid: View {
    let kpis: ActivityKPIs

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ActivityKPIRing(
                label: "Steps / Day",
                value: "\(kpis.avgSteps.formatted())",
                goalLabel: "Goal: \(Int(ActivityConstants.stepsGoal).formatted())",
                period: "Last \(kpis.priorDays) Days",
                fraction: Double(kpis.avgSteps) / ActivityConstants.stepsGoal,
                accentColor: kpiColor(
                    Double(kpis.avgSteps),
                    good: ActivityConstants.stepsGoal,
                    ok: ActivityConstants.stepsOk
                )
            )

            ActivityKPIRing(
                label: "Stand Min / Day",
                value: "\(Int(kpis.avgStandMin))min",
                goalLabel: "Goal: \(Int(ActivityConstants.standGoalMin))min",
                period: "Last \(kpis.priorDays) Days",
                fraction: kpis.avgStandMin / ActivityConstants.standGoalMin,
                accentColor: kpiColor(
                    kpis.avgStandMin,
                    good: ActivityConstants.standGoalMin,
                    ok: ActivityConstants.standOkMin
                )
            )

            ActivityKPIRing(
                label: "Walk Speed",
                value: String(format: "%.2f km/h", kpis.avgWalkingSpeed),
                goalLabel: "≥\(String(format: "%.1f", ActivityConstants.walkSpeedGoal)) km/h",
                period: "Last \(kpis.priorDays) Days",
                fraction: kpis.avgWalkingSpeed / ActivityConstants.walkSpeedGoal,
                accentColor: kpiColor(
                    kpis.avgWalkingSpeed,
                    good: ActivityConstants.walkSpeedGoal,
                    ok: ActivityConstants.walkSpeedOk
                )
            )
        }
    }

    private func kpiColor(_ value: Double, good: Double, ok: Double) -> Color {
        if value >= good { return .activityGood }
        if value >= ok   { return .activityOk }
        return .activityBad
    }
}

// MARK: - Ring cell

private struct ActivityKPIRing: View {
    let label: String
    let value: String
    let goalLabel: String
    let period: String
    let fraction: Double
    let accentColor: Color

    private let cardBg = Color(hex: 0x0A1A24)
    private let trackColor = Color.white.opacity(0.06)
    private let ringSize: CGFloat = 90

    private var clampedFraction: Double { max(0, min(1.5, fraction)) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: 7)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: min(1, clampedFraction))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(value)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 6)
            }

            VStack(spacing: 1) {
                Text(period)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))

                Text(goalLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
