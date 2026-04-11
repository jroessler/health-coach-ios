import SwiftUI
import Charts

struct PreWorkoutChart: View {
    let points: [PreWorkoutPoint]
    let targets: PreWorkoutTargets?

    private var axisMax: Double { NutritionConstants.preWorkoutChartAxisMaxMinutes }

    /// Plot x = axisMax − minutesBefore so axis can read 200→0 left-to-right (Streamlit parity).
    private func plotX(minutesBefore: Double) -> Double {
        axisMax - minutesBefore
    }

    var body: some View {
        if points.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                RectangleMark(
                    xStart: .value("lo", plotX(minutesBefore: Double(NutritionConstants.preWorkoutTimingGoodMax))),
                    xEnd: .value("hi", plotX(minutesBefore: Double(NutritionConstants.preWorkoutTimingGoodMin))),
                    yStart: nil,
                    yEnd: nil
                )
                .foregroundStyle(Color(hex: 0x10B981, opacity: 0.08))

                if let t = targets {
                    RuleMark(y: .value("Protein target", t.proteinTargetG))
                        .foregroundStyle(Color(hex: 0x3B82F6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))

                    RuleMark(y: .value("Carbs target", t.carbsTargetG))
                        .foregroundStyle(Color(hex: 0x10B981))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                }

                ForEach(points) { point in
                    PointMark(
                        x: .value("Minutes Before", plotX(minutesBefore: Double(point.minutesBefore))),
                        y: .value("Protein (g)", point.proteinG)
                    )
                    .foregroundStyle(color(for: point.timingQuality))
                    .symbolSize(markerSize(carbsG: point.carbsG))
                }
            }
            .chartXScale(domain: 0...axisMax)
            .chartXAxisLabel("Minutes Before Workout")
            .chartYAxisLabel("Protein (g)")
            .chartXAxis {
                AxisMarks(values: .stride(by: 20)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let v = value.as(Double.self) {
                        let minutes = Int((axisMax - v).rounded())
                        AxisValueLabel {
                            Text("\(minutes)")
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .chartLegend(position: .bottom, spacing: 12)
            .frame(height: 300)

            legend
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                legendItem(color: color(for: .good), label: "60–120 min")
                legendItem(color: color(for: .ok), label: "<60 min")
                legendItem(color: color(for: .bad), label: ">120 min")
            }
            if let t = targets {
                HStack(spacing: 16) {
                    legendDashedRule(
                        color: Color(hex: 0x3B82F6),
                        dash: [4, 4],
                        axis: .horizontal,
                        label: "Protein Target: \(Int(t.proteinTargetG))g"
                    )
                    legendDashedRule(
                        color: Color(hex: 0x10B981),
                        dash: [4, 4],
                        axis: .horizontal,
                        label: "Carbs Target: \(Int(t.carbsTargetG))g"
                    )
                }
            }
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.white.opacity(0.6))
        }
    }

    private enum LegendRuleAxis {
        case horizontal
        case vertical
    }

    private func legendDashedRule(color: Color, dash: [CGFloat], axis: LegendRuleAxis, label: String) -> some View {
        HStack(spacing: 4) {
            legendDashedRuleSwatch(color: color, dash: dash, axis: axis)
            Text(label).foregroundStyle(.white.opacity(0.6))
        }
    }

    private func legendDashedRuleSwatch(color: Color, dash: [CGFloat], axis: LegendRuleAxis) -> some View {
        let w: CGFloat = axis == .horizontal ? 16 : 3
        let h: CGFloat = axis == .horizontal ? 3 : 12
        return Path { path in
            if axis == .horizontal {
                path.move(to: CGPoint(x: 0, y: h / 2))
                path.addLine(to: CGPoint(x: w, y: h / 2))
            } else {
                path.move(to: CGPoint(x: w / 2, y: 0))
                path.addLine(to: CGPoint(x: w / 2, y: h))
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dash))
        .frame(width: w, height: h)
    }

    private func color(for quality: WorkoutTimingQuality) -> Color {
        switch quality {
        case .good: return .kpiGood
        case .ok: return .kpiOk
        case .bad: return .kpiBad
        }
    }

    private func markerSize(carbsG: Double) -> CGFloat {
        let raw = max(carbsG, 5) / 3 + 8
        return CGFloat(raw * raw * 0.3)
    }

    private var emptyState: some View {
        Text("No pre-workout nutrition data found")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
