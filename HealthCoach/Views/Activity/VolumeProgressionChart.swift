import SwiftUI

struct VolumeProgressionChart: View {
    let data: VolumeProgressionData

    // Color scale: purple → near-black → cyan, matching Streamlit colorscale
    private let negativePole = Color(hex: 0xDE49F5)   // purple
    private let midpoint     = Color(hex: 0x021A20)    // near-black
    private let positivePole = Color(hex: 0x22D3EE)    // cyan

    private let rowHeight: CGFloat = 44
    private let colWidth: CGFloat  = 90
    private let muscleColWidth: CGFloat = 72

    var body: some View {
        if data.muscles.isEmpty || data.weekLabels.isEmpty {
            emptyState
        } else {
            heatmapContent
        }
    }

    private var emptyState: some View {
        Text("Not enough data for progression heatmap")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var heatmapContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                headerRow

                // Data rows
                ForEach(data.muscles.indices, id: \.self) { mIdx in
                    dataRow(muscleIndex: mIdx)
                }

                // Color legend
                colorLegend
                    .padding(.top, 12)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Muscle label column spacer
            Text("")
                .frame(width: muscleColWidth, alignment: .leading)

            ForEach(data.weekLabels.indices, id: \.self) { wIdx in
                Text(shortWeekLabel(data.weekLabels[wIdx]))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: colWidth, height: rowHeight, alignment: .center)
            }
        }
    }

    private func dataRow(muscleIndex mIdx: Int) -> some View {
        let muscle = data.muscles[mIdx]
        return HStack(spacing: 0) {
            // Muscle label
            Text(muscle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFFE4B5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: muscleColWidth, alignment: .leading)

            ForEach(data.weekLabels.indices, id: \.self) { wIdx in
                let pct = data.pctChange[mIdx][wIdx]
                let curVol = data.weeklyVolume[mIdx][wIdx]
                let prevVol = data.priorVolume[mIdx][wIdx]
                cell(pct: pct, currentVol: curVol, priorVol: prevVol)
            }
        }
    }

    private func cell(pct: Double, currentVol: Double, priorVol: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(cellColor(pct: pct))

            Text(pct == 0 ? "0%" : String(format: "%+.0f%%", pct))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: colWidth - 4, height: rowHeight - 6)
        .padding(2)
        .help("Current: \(Int(currentVol)) kg · Prior: \(Int(priorVol)) kg")
    }

    // MARK: - Color interpolation

    private func cellColor(pct: Double) -> Color {
        // Clamp to ±50 for visual saturation (matching zmin=-50, zmax=50 in Streamlit)
        let clamped = max(-50, min(50, pct))
        if clamped < 0 {
            // negative: midpoint → purple
            let t = -clamped / 50
            return interpolate(from: midpoint, to: negativePole, t: t)
        } else if clamped > 0 {
            // positive: midpoint → cyan
            let t = clamped / 50
            return interpolate(from: midpoint, to: positivePole, t: t)
        } else {
            return midpoint
        }
    }

    private func interpolate(from: Color, to: Color, t: Double) -> Color {
        let t = max(0, min(1, t))
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        UIColor(from).getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        UIColor(to).getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return Color(
            red: Double(fr + (tr - fr) * t),
            green: Double(fg + (tg - fg) * t),
            blue: Double(fb + (tb - fb) * t)
        )
    }

    // MARK: - Helpers

    private func shortWeekLabel(_ label: String) -> String {
        // "28.04.25 - 04.05.25" → "28.04\n04.05"
        let parts = label.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return label }
        let trim: (String) -> String = { s in
            let p = s.split(separator: ".")
            guard p.count >= 2 else { return s }
            return "\(p[0]).\(p[1])"
        }
        return "\(trim(parts[0]))\n\(trim(parts[1]))"
    }

    private var colorLegend: some View {
        HStack(spacing: 8) {
            Text("Less volume")
                .font(.caption2)
                .foregroundStyle(negativePole)

            LinearGradient(
                colors: [negativePole, midpoint, positivePole],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)
            .clipShape(Capsule())

            Text("More volume")
                .font(.caption2)
                .foregroundStyle(positivePole)
        }
        .frame(maxWidth: .infinity)
    }
}
