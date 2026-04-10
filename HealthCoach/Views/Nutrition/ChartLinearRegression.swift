import Foundation

enum ChartLinearRegression {
    /// Ordinary least squares: y ≈ slope * x + intercept
    static func slopeIntercept(xs: [Double], ys: [Double]) -> (slope: Double, intercept: Double)? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        let n = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        var sumXY = 0.0
        var sumX2 = 0.0
        for i in xs.indices {
            sumXY += xs[i] * ys[i]
            sumX2 += xs[i] * xs[i]
        }
        let denom = n * sumX2 - sumX * sumX
        guard abs(denom) > 1e-12 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }
}
