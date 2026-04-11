import Foundation
import GRDB

final class HealthRecordStore: Sendable {
    static let shared = HealthRecordStore()

    private let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = appSupport.appendingPathComponent("health_records.db")
            dbQueue = try DatabaseQueue(path: dbURL.path)
            try migrator.migrate(dbQueue)
        } catch {
            fatalError("HealthRecordStore: failed to open database – \(error)")
        }
    }

    // MARK: - Schema

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_health_records") { db in
            try db.create(table: "health_records", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("category", .text).notNull()
                t.column("metric", .text).notNull()
                t.column("value", .double).notNull()
                t.column("unit", .text)
                t.column("source", .text)
                t.column("start_date", .text)
                t.column("end_date", .text)
                t.column("date", .text).notNull()
            }

            try db.create(
                index: "idx_health_records_metric_date",
                on: "health_records",
                columns: ["metric", "date"],
                ifNotExists: true
            )
        }

        return migrator
    }

    // MARK: - GRDB Record

    struct Record: Codable, FetchableRecord, PersistableRecord {
        var id: Int64?
        var category: String
        var metric: String
        var value: Double
        var unit: String?
        var source: String?
        var startDate: String?
        var endDate: String?
        var date: String

        static let databaseTableName = "health_records"

        enum CodingKeys: String, CodingKey {
            case id, category, metric, value, unit, source
            case startDate = "start_date"
            case endDate = "end_date"
            case date
        }
    }

    // MARK: - Insert

    func insertRecords(_ records: [Record]) throws {
        try dbQueue.write { db in
            for record in records {
                _ = try record.inserted(db)
            }
        }
    }

    // MARK: - Dedup: delete existing records for a metric within a date range

    func deleteRecords(metric: String, startDate: Date, endDate: Date) throws {
        let startStr = Self.dayFormatter.string(from: startDate)
        let endStr = Self.dayFormatter.string(from: endDate)
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM health_records WHERE metric = ? AND date >= ? AND date <= ?",
                arguments: [metric, startStr, endStr]
            )
        }
    }

    func deleteAllRecords() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM health_records")
        }
    }

    // MARK: - Queries (SQL-level aggregation)

    struct ScaleRow: Sendable {
        let date: Date
        var weightKg: Double?
        var fatPercent: Double?
    }

    /// GROUP BY date, returning one row per day with weight and body fat.
    /// Body fat is stored as a fraction in HealthKit; multiply by 100 to get percentage.
    func loadScale() throws -> [ScaleRow] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    date AS date_str,
                    MAX(CASE WHEN metric = 'weight_kg' THEN value END) AS weight_kg,
                    MAX(CASE WHEN metric = 'body_fat_pct' THEN value END) AS fat_pct
                FROM health_records
                WHERE metric IN ('weight_kg', 'body_fat_pct')
                GROUP BY date
                ORDER BY date
            """)
            return rows.compactMap { row -> ScaleRow? in
                guard let dateStr: String = row["date_str"],
                      let date = Self.dayFormatter.date(from: dateStr) else { return nil }
                let fatRaw: Double? = row["fat_pct"]
                return ScaleRow(
                    date: date,
                    weightKg: row["weight_kg"],
                    fatPercent: fatRaw.map { $0 * 100 }
                )
            }
        }
    }

    struct TDEERow: Sendable {
        let date: Date
        var appleTDEE: Double
    }

    /// GROUP BY date, summing basal + active energy into daily TDEE.
    func loadDailyTDEE() throws -> [TDEERow] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    date AS date_str,
                    SUM(CASE WHEN metric = 'basal_energy' THEN value ELSE 0 END) +
                    SUM(CASE WHEN metric = 'active_energy' THEN value ELSE 0 END) AS apple_tdee
                FROM health_records
                WHERE metric IN ('basal_energy', 'active_energy') AND date IS NOT NULL
                GROUP BY date
                ORDER BY date
            """)
            return rows.compactMap { row -> TDEERow? in
                guard let dateStr: String = row["date_str"],
                      let date = Self.dayFormatter.date(from: dateStr) else { return nil }
                return TDEERow(date: date, appleTDEE: row["apple_tdee"] ?? 0)
            }
        }
    }

    // MARK: - Activity daily aggregates

    struct ActivityDailyRow: Sendable {
        let date: Date
        let activeEnergyKcal: Double
        let basalEnergyKcal: Double
        let steps: Double
        let exerciseMin: Double
        let standMin: Double
        /// nil when no walking_speed records exist for this date — mirrors Python AVG returning NULL.
        let walkingSpeedKmh: Double?
        let daylightMin: Double
    }

    /// Mirrors load_activity() in activity.py — one row per day with aggregated activity metrics.
    func loadActivityDaily() throws -> [ActivityDailyRow] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    date AS date_str,
                    SUM(CASE WHEN metric = 'active_energy'    THEN value ELSE 0 END) AS active_energy_kcal,
                    SUM(CASE WHEN metric = 'basal_energy'     THEN value ELSE 0 END) AS basal_energy_kcal,
                    SUM(CASE WHEN metric = 'steps'            THEN value ELSE 0 END) AS steps,
                    SUM(CASE WHEN metric = 'exercise_minutes' THEN value ELSE 0 END) AS exercise_min,
                    SUM(CASE WHEN metric = 'stand_minutes'    THEN value ELSE 0 END) AS stand_min,
                    AVG(CASE WHEN metric = 'walking_speed'    THEN value END)        AS walking_speed_kmh,
                    SUM(CASE WHEN metric = 'time_in_daylight' THEN value ELSE 0 END) AS daylight_min
                FROM health_records
                WHERE metric IN (
                    'active_energy', 'basal_energy', 'steps',
                    'exercise_minutes', 'stand_minutes',
                    'walking_speed', 'time_in_daylight'
                )
                AND date IS NOT NULL
                GROUP BY date
                ORDER BY date
            """)
            return rows.compactMap { row -> ActivityDailyRow? in
                guard let dateStr: String = row["date_str"],
                      let date = Self.dayFormatter.date(from: dateStr) else { return nil }
                return ActivityDailyRow(
                    date: date,
                    activeEnergyKcal: row["active_energy_kcal"] ?? 0,
                    basalEnergyKcal: row["basal_energy_kcal"] ?? 0,
                    steps: row["steps"] ?? 0,
                    exerciseMin: row["exercise_min"] ?? 0,
                    standMin: row["stand_min"] ?? 0,
                    walkingSpeedKmh: row["walking_speed_kmh"],   // nil when no data — mirrors Python NaN skip
                    daylightMin: row["daylight_min"] ?? 0
                )
            }
        }
    }

    // MARK: - Dashboard stats

    func countRecords() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM health_records") ?? 0
        }
    }

    func dateRange() throws -> (min: String?, max: String?) {
        try dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT MIN(date) AS min_d, MAX(date) AS max_d FROM health_records")
            return (min: row?["min_d"], max: row?["max_d"])
        }
    }

    // MARK: - Date Formatter

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}
