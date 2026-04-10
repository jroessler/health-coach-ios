import Foundation

final class HevyAPIService {
    private let baseURL = "https://api.hevyapp.com"

    // MARK: - API Response Models

    struct WorkoutsPage: Decodable {
        let workouts: [APIWorkout]?
        let pageCount: Int?

        enum CodingKeys: String, CodingKey {
            case workouts
            case pageCount = "page_count"
            case pageCountCamel = "pageCount"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            workouts = try c.decodeIfPresent([APIWorkout].self, forKey: .workouts)
            pageCount = try c.decodeIfPresent(Int.self, forKey: .pageCount)
                ?? c.decodeIfPresent(Int.self, forKey: .pageCountCamel)
        }
    }

    struct APIWorkout: Decodable {
        let title: String?
        let startTime: String?
        let endTime: String?
        let description: String?
        let notes: String?
        let exercises: [APIExercise]?

        enum CodingKeys: String, CodingKey {
            case title, description, notes, exercises
            case startTime = "start_time"
            case startTimeCamel = "startTime"
            case endTime = "end_time"
            case endTimeCamel = "endTime"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            description = try c.decodeIfPresent(String.self, forKey: .description)
            notes = try c.decodeIfPresent(String.self, forKey: .notes)
            exercises = try c.decodeIfPresent([APIExercise].self, forKey: .exercises)
            startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
                ?? c.decodeIfPresent(String.self, forKey: .startTimeCamel)
            endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
                ?? c.decodeIfPresent(String.self, forKey: .endTimeCamel)
        }
    }

    struct APIExercise: Decodable {
        let title: String?
        let supersetsId: Int?
        let notes: String?
        let sets: [APISet]?

        enum CodingKeys: String, CodingKey {
            case title, notes, sets
            case supersetsId = "supersets_id"
        }
    }

    struct APISet: Decodable {
        let index: Int?
        let type: String?
        let weightKg: Double?
        let reps: Int?
        let distanceMeters: Double?
        let durationSeconds: Double?
        let rpe: Double?

        enum CodingKeys: String, CodingKey {
            case index, type, reps, rpe
            case weightKg = "weight_kg"
            case distanceMeters = "distance_meters"
            case durationSeconds = "duration_seconds"
        }
    }

    struct TemplatesPage: Decodable {
        let exerciseTemplates: [APITemplate]?
        let pageCount: Int?

        enum CodingKeys: String, CodingKey {
            case pageCount = "page_count"
            case pageCountCamel = "pageCount"
            case exerciseTemplates = "exercise_templates"
            case exerciseTemplatesCamel = "exerciseTemplates"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            exerciseTemplates = try c.decodeIfPresent([APITemplate].self, forKey: .exerciseTemplates)
                ?? c.decodeIfPresent([APITemplate].self, forKey: .exerciseTemplatesCamel)
            pageCount = try c.decodeIfPresent(Int.self, forKey: .pageCount)
                ?? c.decodeIfPresent(Int.self, forKey: .pageCountCamel)
        }
    }

    struct APITemplate: Decodable {
        let id: String?
        let exerciseTemplateId: String?
        let title: String?
        let type: String?
        let primaryMuscleGroup: String?
        let secondaryMuscleGroups: SecondaryMuscles?
        let equipmentCategory: String?

        enum CodingKeys: String, CodingKey {
            case id, title, type
            case exerciseTemplateId = "exercise_template_id"
            case primaryMuscleGroup = "primary_muscle_group"
            case secondaryMuscleGroups = "secondary_muscle_groups"
            case equipmentCategory = "equipment_category"
        }

        var resolvedId: String? { id ?? exerciseTemplateId }
    }

    enum SecondaryMuscles: Decodable {
        case list([String])
        case single(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let list = try? container.decode([String].self) {
                self = .list(list)
            } else if let single = try? container.decode(String.self) {
                self = .single(single)
            } else {
                self = .list([])
            }
        }

        var joined: String? {
            switch self {
            case .list(let items): return items.isEmpty ? nil : items.joined(separator: ",")
            case .single(let s): return s
            }
        }
    }

    // MARK: - ISO Date Parsing (mirrors normalize_iso in fetch_hevy_api.py)

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseISO(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return isoFormatter.date(from: trimmed) ?? isoFormatterNoFrac.date(from: trimmed)
    }

    private static func formatISO(_ date: Date) -> String {
        isoFormatterNoFrac.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Fetch All Workouts

    func fetchAllWorkouts(apiKey: String) async throws -> [APIWorkout] {
        var all: [APIWorkout] = []
        var page = 1
        let pageSize = 10

        while true {
            var components = URLComponents(string: "\(baseURL)/v1/workouts")!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            ]
            var request = URLRequest(url: components.url!)
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validateResponse(response)

            let decoded = try JSONDecoder().decode(WorkoutsPage.self, from: data)
            let pageWorkouts = decoded.workouts ?? []
            all.append(contentsOf: pageWorkouts)

            let totalPages = decoded.pageCount ?? page
            if page >= totalPages || pageWorkouts.isEmpty { break }
            page += 1
        }

        return all
    }

    // MARK: - Fetch All Exercise Templates

    func fetchAllExerciseTemplates(apiKey: String) async throws -> [APITemplate] {
        var all: [APITemplate] = []
        var page = 1
        let pageSize = 100

        while true {
            var components = URLComponents(string: "\(baseURL)/v1/exercise_templates")!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            ]
            var request = URLRequest(url: components.url!)
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validateResponse(response)

            let decoded = try JSONDecoder().decode(TemplatesPage.self, from: data)
            let pageTemplates = decoded.exerciseTemplates ?? []
            all.append(contentsOf: pageTemplates)

            let totalPages = decoded.pageCount ?? page
            if page >= totalPages || pageTemplates.isEmpty { break }
            page += 1
        }

        return all
    }

    // MARK: - Convert API models to SwiftData models

    func buildWorkoutsAndSets(
        from apiWorkouts: [APIWorkout],
        existingKeys: Set<String>
    ) -> (workouts: [Workout], sets: [WorkoutSet]) {
        var workouts: [Workout] = []
        var sets: [WorkoutSet] = []

        for w in apiWorkouts {
            let title = w.title ?? ""
            guard let startRaw = w.startTime, let endRaw = w.endTime,
                  let startDt = Self.parseISO(startRaw), let endDt = Self.parseISO(endRaw) else {
                continue
            }

            let startISO = Self.formatISO(startDt)
            let endISO = Self.formatISO(endDt)
            let key = "\(title)|\(startISO)"

            if existingKeys.contains(key) { continue }

            let durationMin = (endDt.timeIntervalSince(startDt) / 60.0 * 10).rounded() / 10.0
            let date = Self.dayFormatter.string(from: startDt)
            let desc = w.description ?? w.notes ?? ""

            let workout = Workout(
                title: title,
                startTime: startISO,
                endTime: endISO,
                durationMin: durationMin,
                workoutDescription: desc,
                date: date
            )

            for exercise in w.exercises ?? [] {
                for s in exercise.sets ?? [] {
                    let ws = WorkoutSet(exerciseTitle: exercise.title ?? "", date: date)
                    ws.supersetId = exercise.supersetsId.map { String($0) }
                    ws.exerciseNotes = exercise.notes
                    ws.setIndex = s.index
                    ws.setType = s.type
                    ws.weightKg = s.weightKg
                    ws.reps = s.reps
                    ws.distanceKm = s.distanceMeters.map { $0 / 1000.0 }
                    ws.durationSeconds = s.durationSeconds
                    ws.rpe = s.rpe
                    ws.workout = workout
                    sets.append(ws)
                }
            }

            workouts.append(workout)
        }

        return (workouts, sets)
    }

    func buildExerciseTemplates(from apiTemplates: [APITemplate]) -> [ExerciseTemplate] {
        apiTemplates.compactMap { t in
            guard let id = t.resolvedId else { return nil }
            let template = ExerciseTemplate(templateId: id, title: t.title ?? "")
            template.exerciseType = t.type
            template.muscle = t.primaryMuscleGroup
            template.secondaryMuscle = t.secondaryMuscleGroups?.joined
            template.equipmentCategory = t.equipmentCategory
            return template
        }
    }

    // MARK: - Helpers

    private static func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw HevyAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw HevyAPIError.httpError(statusCode: http.statusCode)
        }
    }
}

enum HevyAPIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Hevy API key not configured. Add it in Settings."
        case .invalidResponse:
            return "Invalid response from Hevy API."
        case .httpError(let code):
            return "Hevy API returned HTTP \(code)."
        }
    }
}
