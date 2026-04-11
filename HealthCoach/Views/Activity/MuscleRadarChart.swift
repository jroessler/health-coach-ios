import SwiftUI

struct MuscleRadarChart: View {
    let data: MuscleRadarData

    private let muscles = ActivityConstants.radarMuscles
    private let axisLevels: [Double] = [25, 50, 75, 100, 125, 150]

    private let currentColor = Color(hex: 0x3B82F6)
    private let gridColor    = Color.white.opacity(0.1)
    private let labelColor   = Color(hex: 0xFFE4B5)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: side / 2)
            let maxRadius = side / 2 * 0.68

            ZStack {
                // Grid rings
                ForEach(axisLevels, id: \.self) { level in
                    radarPolygon(
                        values: Array(repeating: level, count: muscles.count),
                        maxValue: 150,
                        maxRadius: maxRadius,
                        center: center
                    )
                    .stroke(gridColor, lineWidth: level == 100 ? 1.0 : 0.5)
                }

                // Axis spokes
                ForEach(0..<muscles.count, id: \.self) { i in
                    let angle = angleFor(index: i, count: muscles.count)
                    let tip = pointOnCircle(center: center, radius: maxRadius, angle: angle)
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: tip)
                    }
                    .stroke(gridColor, lineWidth: 0.5)
                }

                // Current polygon (filled)
                radarPolygon(
                    values: currentNormValues,
                    maxValue: 150,
                    maxRadius: maxRadius,
                    center: center
                )
                .fill(currentColor.opacity(0.15))

                radarPolygon(
                    values: currentNormValues,
                    maxValue: 150,
                    maxRadius: maxRadius,
                    center: center
                )
                .stroke(currentColor, lineWidth: 3)

                // Tick labels (25 / 50 / 75 / 100 / 125 / 150%)
                axisTickLabels(center: center, maxRadius: maxRadius)

                // Muscle labels
                ForEach(0..<muscles.count, id: \.self) { i in
                    let angle = angleFor(index: i, count: muscles.count)
                    let labelRadius = maxRadius + 26
                    let pt = pointOnCircle(center: center, radius: labelRadius, angle: angle)
                    Text(muscles[i])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(labelColor)
                        .multilineTextAlignment(.center)
                        .position(pt)
                }
            }
        }
        .frame(height: 320)
        .padding(.bottom, 16)
    }

    // MARK: - Legend

    var legendView: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(currentColor)
                .frame(width: 16, height: 3)
            Text("Last \(data.daysUsed)d")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed values

    private var currentNormValues: [Double] {
        muscles.map { m in
            let ratio = data.currentRatios[m] ?? 0
            return max(0, min(1.5, ratio)) * 100
        }
    }

    // MARK: - Drawing helpers

    /// Returns the angle in radians for vertex i of an n-sided polygon, starting at top (-π/2).
    private func angleFor(index: Int, count: Int) -> Double {
        -(.pi / 2) + 2 * .pi * Double(index) / Double(count)
    }

    private func pointOnCircle(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func radarPolygon(
        values: [Double],
        maxValue: Double,
        maxRadius: Double,
        center: CGPoint
    ) -> Path {
        Path { path in
            let count = values.count
            guard count > 0 else { return }
            for (i, value) in values.enumerated() {
                let fraction = max(0, value) / maxValue
                let radius = fraction * maxRadius
                let angle = angleFor(index: i, count: count)
                let pt = pointOnCircle(center: center, radius: radius, angle: angle)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        }
    }

    @ViewBuilder
    private func axisTickLabels(center: CGPoint, maxRadius: Double) -> some View {
        // Place tick labels along the first axis (top, slightly offset)
        let angle = angleFor(index: 0, count: muscles.count)
        ForEach(axisLevels, id: \.self) { level in
            let fraction = level / 150
            let radius = fraction * maxRadius
            let pt = pointOnCircle(center: center, radius: radius, angle: angle)
            Text("\(Int(level))%")
                .font(.system(size: 8))
                .foregroundStyle(Color.white.opacity(0.4))
                .position(x: pt.x + 14, y: pt.y)
        }
    }
}
