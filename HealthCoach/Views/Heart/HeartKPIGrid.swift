import SwiftUI

// MARK: - Recovery KPI Section

struct RecoveryKPISection: View {
    let kpis: RecoveryKPIs
    let periodLength: Int
    let baselineDaysHRV: Int
    let baselineDaysRHR: Int

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var displayPeriod: Int { min(7, periodLength) }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // Recovery Score
            HeartKPICard(
                label: "Recovery Score (Last \(displayPeriod)D)",
                value: "\(scoreLabel) (\(kpis.recoveryScore)/100)",
                accentColor: scoreColor
            )

            // HRV — round to nearest (matches Python's :.0f format)
            HeartKPICard(
                label: "HRV (\(displayPeriod)d) vs Baseline (\(baselineDaysHRV)d)",
                value: "\(Int(kpis.hrvToday.rounded())) ms (\(formatted(kpis.hrvPct))%)",
                accentColor: hrvColor
            )

            // RHR — round to nearest (matches Python's :.0f format)
            HeartKPICard(
                label: "RHR (\(displayPeriod)d) vs Baseline (\(baselineDaysRHR)d)",
                value: "\(Int(kpis.rhrToday.rounded())) bpm (\(formatted(kpis.rhrPct))%)",
                accentColor: rhrColor
            )

            // HRV/RHR Signal
            HeartKPICardWithSubtitle(
                label: "HRV / RHR Signal",
                value: kpis.divergenceLabel,
                subtitle: kpis.divergenceDetail,
                accentColor: divergenceColor
            )
        }
    }

    // MARK: - Computed colors

    private var scoreColor: Color {
        let s = kpis.recoveryScore
        if s >= 80 { return Color(hex: 0x059669) }
        if s >= 60 { return Color(hex: 0x10B981) }
        if s >= 45 { return Color(hex: 0x6EE7B7) }
        if s >= 30 { return Color(hex: 0xF97316) }
        return Color(hex: 0xEF4444)
    }

    private var scoreLabel: String {
        let s = kpis.recoveryScore
        if s >= 80 { return "Excellent" }
        if s >= 60 { return "Very Good" }
        if s >= 45 { return "Good" }
        if s >= 30 { return "Low" }
        return "Poor"
    }

    private var hrvColor: Color {
        if kpis.hrvZ >= -1 { return .kpiGood }
        if kpis.hrvZ >= -2 { return .kpiOk }
        return .kpiBad
    }

    private var rhrColor: Color {
        if kpis.rhrZ >= -1 { return .kpiGood }
        if kpis.rhrZ >= -2 { return .kpiOk }
        return .kpiBad
    }

    private var divergenceColor: Color {
        let d = kpis.divergence
        if d >= 1.0 { return Color(hex: 0x059669) }
        if d >= 0.25 { return Color(hex: 0x10B981) }
        if d >= -0.25 { return Color(hex: 0x6EE7B7) }
        if d >= -1.0 { return Color(hex: 0xF97316) }
        return Color(hex: 0xEF4444)
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }
}

// MARK: - Fitness KPI Section

struct FitnessKPISection: View {
    let kpis: FitnessKPIs
    let periodLength: Int

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var displayPeriod14: Int { min(14, periodLength) }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // VO2 Current
            HeartKPICardWithSubtitle(
                label: "VO₂ Max (Last)",
                value: vo2Value,
                subtitle: "Goal: \(Int(HeartConstants.vo2LongevityGoal)) ml/kg/min",
                accentColor: vo2Color
            )

            // VO2 Delta
            HeartKPICard(
                label: "VO₂ Max (\(displayPeriod14)D Avg) vs Baseline (30D)",
                value: vo2DeltaValue,
                accentColor: vo2DeltaColor
            )
        }
    }

    private var vo2Value: String {
        guard let v = kpis.vo2Current else { return "N/A" }
        return String(format: "%.1f ml/kg/min", v)
    }

    private var vo2Color: Color {
        guard let v = kpis.vo2Current else { return .kpiNeutral }
        if v >= kpis.vo2AgeRefs.elite { return .kpiGood }
        if v >= kpis.vo2AgeRefs.average { return .kpiOk }
        return .kpiBad
    }

    private var vo2DeltaValue: String {
        guard let d = kpis.vo2Delta30d else { return "N/A" }
        return String(format: "%+.1f", d)
    }

    private var vo2DeltaColor: Color {
        guard let d = kpis.vo2Delta30d else { return .kpiNeutral }
        return d >= 0 ? .kpiGood : .kpiBad
    }
}

// MARK: - KPI Card Components

struct HeartKPICard: View {
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                    .minimumScaleFactor(0.55)
                    .lineLimit(2)
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

struct HeartKPICardWithSubtitle: View {
    let label: String
    let value: String
    let subtitle: String
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
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
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
