import SwiftUI
import Charts

struct PostWorkoutChart: View {
    let points: [PostWorkoutPoint]

    private let proteinTarget = NutritionConstants.proteinPostWorkoutTargetG
    private let minutesTarget = NutritionConstants.postWorkoutTimingTargetMin

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
                    xStart: .value("lo", 0),
                    xEnd: .value("hi", minutesTarget),
                    yStart: nil,
                    yEnd: nil
                )
                .foregroundStyle(Color(hex: 0x10B981, opacity: 0.05))

                RuleMark(x: .value("Time Target", minutesTarget))
                    .foregroundStyle(Color(hex: 0xFBBF24))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                RuleMark(y: .value("Protein Target", proteinTarget))
                    .foregroundStyle(Color(hex: 0x3B82F6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))

                ForEach(points) { point in
                    PointMark(
                        x: .value("Minutes After", point.minutesAfter),
                        y: .value("Protein (g)", point.proteinG)
                    )
                    .foregroundStyle(color(for: point.quadrant))
                    .symbolSize(120)
                }
            }
            .chartXScale(domain: 0...130)
            .chartYScale(domain: 0...150)
            .chartXAxisLabel("Minutes After Workout")
            .chartYAxisLabel("Protein (g)")
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.6))
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
                legendItem(color: color(for: .good), label: "Optimal")
                legendItem(color: color(for: .ok), label: "Partially met")
                legendItem(color: color(for: .bad), label: "Both missed")
            }
            HStack(spacing: 16) {
                legendDashedRule(
                    color: Color(hex: 0xFBBF24),
                    dash: [6, 4],
                    axis: .vertical,
                    label: "\(Int(minutesTarget)) min target"
                )
                legendDashedRule(
                    color: Color(hex: 0x3B82F6),
                    dash: [4, 4],
                    axis: .horizontal,
                    label: "Protein target: \(Int(proteinTarget))g"
                )
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

    private var emptyState: some View {
        Text("No post-workout nutrition data found")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
