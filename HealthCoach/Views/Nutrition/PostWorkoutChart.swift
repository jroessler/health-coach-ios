import SwiftUI
import Charts

struct PostWorkoutChart: View {
    let points: [PostWorkoutPoint]

    private let proteinTarget = NutritionConstants.proteinPostWorkoutTargetG
    private let minutesTarget = NutritionConstants.postWorkoutTimingTargetMin
    private let trendName = "Trend (protein vs timing)"

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
                    .annotation(position: .topTrailing) {
                        Text("120 min")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: 0xFBBF24))
                    }

                RuleMark(y: .value("Protein Target", proteinTarget))
                    .foregroundStyle(Color(hex: 0x3B82F6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .annotation(position: .topLeading) {
                        Text("\(Int(proteinTarget))g protein")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: 0x3B82F6))
                    }

                if let seg = trendSegment {
                    LineMark(
                        x: .value("Minutes After", seg.x0),
                        y: .value("Protein (g)", seg.y0),
                        series: .value("Series", trendName)
                    )
                    .foregroundStyle(by: .value("Series", trendName))
                    LineMark(
                        x: .value("Minutes After", seg.x1),
                        y: .value("Protein (g)", seg.y1),
                        series: .value("Series", trendName)
                    )
                    .foregroundStyle(by: .value("Series", trendName))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(points) { point in
                    PointMark(
                        x: .value("Minutes After", point.minutesAfter),
                        y: .value("Protein (g)", point.proteinG)
                    )
                    .foregroundStyle(color(for: point.quadrant))
                    .symbolSize(120)
                }
            }
            .chartForegroundStyleScale([
                trendName: Color.white.opacity(0.55),
            ])
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

    private var trendSegment: (x0: Double, y0: Double, x1: Double, y1: Double)? {
        let xs = points.map { Double($0.minutesAfter) }
        let ys = points.map(\.proteinG)
        guard let fit = ChartLinearRegression.slopeIntercept(xs: xs, ys: ys) else { return nil }
        let xLo = xs.min() ?? 0
        let xHi = xs.max() ?? 0
        guard xHi > xLo else { return nil }
        let y0 = fit.slope * xLo + fit.intercept
        let y1 = fit.slope * xHi + fit.intercept
        return (xLo, y0, xHi, y1)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: color(for: .good), label: "Optimal")
            legendItem(color: color(for: .ok), label: "Partially met")
            legendItem(color: color(for: .bad), label: "Both missed")
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.white.opacity(0.6))
        }
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
