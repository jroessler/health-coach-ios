import Foundation

// Pure nutrition KPI pipeline (filter_macros → compute_macro_pct → compute_kpi_values).
// Shared with NutritionComputer and unit tests.

struct NutritionMacroAggregate: Sendable {
    let date: Date
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var protPct: Double?
    var carbPct: Double?
    var fatPct: Double?

    init(
        date: Date,
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        protPct: Double? = nil,
        carbPct: Double? = nil,
        fatPct: Double? = nil
    ) {
        self.date = date
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.protPct = protPct
        self.carbPct = carbPct
        self.fatPct = fatPct
    }
}

struct NutritionScaleAggregate: Sendable {
    let date: Date
    var weightKg: Double?
    var fatPercent: Double?
}

enum NutritionKPIMath {

    static func filterMacros(
        _ rows: [NutritionMacroAggregate],
        dateStart: Date,
        dateEnd: Date
    ) -> [NutritionMacroAggregate] {
        rows.filter {
            $0.date >= dateStart && $0.date <= dateEnd && $0.calories >= NutritionConstants.minCaloriesForFiltering
        }
    }

    static func computeMacroPct(_ rows: [NutritionMacroAggregate]) -> [NutritionMacroAggregate] {
        rows.map { row in
            var r = row
            if row.calories > 0 {
                r.protPct = (row.proteinG * NutritionConstants.proteinKcalPerGram / row.calories * 100).rounded(toPlaces: 1)
                r.carbPct = (row.carbsG * NutritionConstants.carbsKcalPerGram / row.calories * 100).rounded(toPlaces: 1)
                r.fatPct = (row.fatG * NutritionConstants.fatKcalPerGram / row.calories * 100).rounded(toPlaces: 1)
            }
            return r
        }
    }

    static func computeKPIValues(
        _ macrosPct: [NutritionMacroAggregate],
        scale: [NutritionScaleAggregate],
        dateStart: Date,
        dateEnd: Date,
        calendar: Calendar
    ) -> NutritionKPIs {
        let macrosInRange = macrosPct.filter { $0.date >= dateStart && $0.date <= dateEnd }
        let scaleInRange = scale.filter { $0.date >= dateStart && $0.date <= dateEnd && $0.weightKg != nil }
            .sorted { $0.date < $1.date }
        let scaleBeforeRange = scale.filter { $0.date < dateStart && $0.weightKg != nil }
            .sorted { $0.date < $1.date }

        let last7Start = max(dateStart, calendar.date(byAdding: .day, value: -6, to: dateEnd)!)
        let last7 = macrosInRange.filter { $0.date >= last7Start && $0.date <= dateEnd }
        let avgCalories7d = last7.isEmpty ? 0.0 : last7.map(\.calories).mean()
        let avgProtein7d = last7.isEmpty ? 0.0 : last7.map(\.proteinG).mean()

        var bfChange: Double?
        var wtChange: Double?

        if !scaleInRange.isEmpty {
            let bfRows = scaleInRange.filter { $0.fatPercent != nil }
            if bfRows.count >= 2 {
                bfChange = ((bfRows.last!.fatPercent! - bfRows.first!.fatPercent!) * 10).rounded() / 10
            }
            if scaleInRange.count >= 2 {
                wtChange = ((scaleInRange.last!.weightKg! - scaleInRange.first!.weightKg!) * 10).rounded() / 10
            }
        }

        // Prefer latest weigh-in inside the chart range; else most recent before rangeStart (no default 75 kg).
        let weightForProteinPerKg = scaleInRange.last?.weightKg ?? scaleBeforeRange.last?.weightKg
        let proteinPerKg: Double?
        if let w = weightForProteinPerKg, w > 0 {
            proteinPerKg = (avgProtein7d / w * 100).rounded() / 100
        } else {
            proteinPerKg = nil
        }

        return NutritionKPIs(
            last7dAvgKcal: avgCalories7d,
            totalBodyFatChange: bfChange,
            totalWeightChange: wtChange,
            sevenDayProteinPerKg: proteinPerKg
        )
    }

    // MARK: - compute_macro_pct_averages (Macro Overview — mean of daily macro %)

    static func computeMacroPctAverages(_ rows: [NutritionMacroAggregate]) -> MacroTargetData {
        guard !rows.isEmpty else { return MacroTargetData(avgProteinPct: nil, avgCarbsPct: nil, avgFatPct: nil) }
        let prots = rows.compactMap(\.protPct)
        let carbs = rows.compactMap(\.carbPct)
        let fats = rows.compactMap(\.fatPct)
        return MacroTargetData(
            avgProteinPct: prots.isEmpty ? nil : prots.mean(),
            avgCarbsPct: carbs.isEmpty ? nil : carbs.mean(),
            avgFatPct: fats.isEmpty ? nil : fats.mean()
        )
    }
}

private extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
