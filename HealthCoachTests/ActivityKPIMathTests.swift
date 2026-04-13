import XCTest
@testable import HealthCoach

/// Goldens for `ActivityKPIMath` — see `docs/activity-computations.md`.
final class ActivityKPIMathTests: XCTestCase {

    private var cal: Calendar { ActivityKPIMath.activityCalendar }

    /// Start of local calendar day (matches Activity date pickers).
    private func sod(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func noon(on day: Date) -> Date {
        cal.date(byAdding: .hour, value: 12, to: cal.startOfDay(for: day))!
    }

    // MARK: - §1 Total workouts

    func testTotalWorkouts_reflectsRawCount_notFilteredByRange() {
        let w = (0..<12).map { i in
            ActivityWorkoutInput(
                date: sod(2026, 1, 1),
                startTime: noon(on: sod(2026, 1, 1)).addingTimeInterval(Double(i)),
                durationMin: 45
            )
        }
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: w,
            totalWorkoutCount: 12,
            dateStart: sod(2026, 6, 1),
            dateEnd: sod(2026, 6, 30)
        )
        XCTAssertEqual(k.totalWorkouts, 12)
    }

    func testNoWorkouts_allWorkoutKPIFieldsZero() {
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: [],
            totalWorkoutCount: 0,
            dateStart: sod(2026, 1, 1),
            dateEnd: sod(2026, 1, 7)
        )
        XCTAssertEqual(k.totalWorkouts, 0)
        XCTAssertEqual(k.workoutsLastN, 0)
        XCTAssertEqual(k.avgDurationOverallMin, 0)
        XCTAssertEqual(k.avgDurationLastNMin, 0)
        XCTAssertEqual(k.avgDurationPriorMin, 0)
        XCTAssertEqual(k.priorDays, 0)
        XCTAssertEqual(k.deltaWorkouts, 0)
        XCTAssertEqual(k.deltaDurationMin, 0)
    }

    // MARK: - §2 Period length & counts

    func testPriorDays_cap30_whenRangeIs90Days() {
        let w = [ActivityWorkoutInput(date: sod(2026, 1, 1), startTime: noon(on: sod(2026, 1, 1)), durationMin: 40)]
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: w,
            totalWorkoutCount: 1,
            dateStart: sod(2026, 1, 1),
            dateEnd: sod(2026, 3, 31)
        )
        XCTAssertEqual(k.priorDays, 30)
    }

    func testPriorDays_matchesRange_whenUnder30Days() {
        let w = [ActivityWorkoutInput(date: sod(2026, 1, 1), startTime: noon(on: sod(2026, 1, 1)), durationMin: 40)]
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: w,
            totalWorkoutCount: 1,
            dateStart: sod(2026, 1, 1),
            dateEnd: sod(2026, 1, 14)
        )
        XCTAssertEqual(k.priorDays, 14)
    }

    func testWorkoutCounts_docExample_X7_deltaPlus2() {
        let ds = sod(2026, 3, 1)
        let de = sod(2026, 3, 7)
        var workouts: [ActivityWorkoutInput] = []
        for i in 0..<3 {
            let day = cal.date(byAdding: .day, value: i, to: sod(2026, 2, 23))!
            workouts.append(ActivityWorkoutInput(date: day, startTime: noon(on: day), durationMin: 40))
        }
        for i in 0..<5 {
            let day = cal.date(byAdding: .day, value: i, to: ds)!
            workouts.append(ActivityWorkoutInput(date: day, startTime: noon(on: day), durationMin: 50))
        }
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: workouts,
            totalWorkoutCount: workouts.count,
            dateStart: ds,
            dateEnd: de
        )
        XCTAssertEqual(k.workoutsLastN, 5)
        XCTAssertEqual(k.priorDays, 7)
        XCTAssertEqual(k.deltaWorkouts, 2)
    }

    func testWorkoutCounts_docExample2_longRange_deltaMinus3() {
        let ds = sod(2026, 1, 1)
        let de = sod(2026, 3, 31)
        var workouts: [ActivityWorkoutInput] = []
        for i in 0..<15 {
            let day = cal.date(byAdding: .day, value: i, to: sod(2025, 12, 2))!
            workouts.append(ActivityWorkoutInput(date: day, startTime: noon(on: day), durationMin: 40))
        }
        // Recent window ends Mar 31 and starts Mar 2 (30d); Mar 1 is outside — place 12 sessions Mar 2…13.
        for i in 0..<12 {
            let day = cal.date(byAdding: .day, value: i, to: sod(2026, 3, 2))!
            workouts.append(ActivityWorkoutInput(date: day, startTime: noon(on: day), durationMin: 45))
        }
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: workouts,
            totalWorkoutCount: workouts.count,
            dateStart: ds,
            dateEnd: de
        )
        XCTAssertEqual(k.priorDays, 30)
        XCTAssertEqual(k.workoutsLastN, 12)
        XCTAssertEqual(k.deltaWorkouts, -3)
    }

    func testRecentWindow_includesWorkoutOnLastCalendarDay_afterMidnight() {
        let ds = sod(2026, 3, 1)
        let de = sod(2026, 3, 31)
        let lastDay = sod(2026, 3, 31)
        let w = [
            ActivityWorkoutInput(date: lastDay, startTime: noon(on: lastDay), durationMin: 60)
        ]
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: w,
            totalWorkoutCount: 1,
            dateStart: ds,
            dateEnd: de
        )
        XCTAssertEqual(k.workoutsLastN, 1)
    }

    // MARK: - §3–4 Duration

    func testAvgDurationOverall_threeSessions() {
        let w = [
            ActivityWorkoutInput(date: sod(2026, 1, 1), startTime: noon(on: sod(2026, 1, 1)), durationMin: 40),
            ActivityWorkoutInput(date: sod(2026, 1, 2), startTime: noon(on: sod(2026, 1, 2)), durationMin: 50),
            ActivityWorkoutInput(date: sod(2026, 1, 3), startTime: noon(on: sod(2026, 1, 3)), durationMin: 60),
        ]
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: w,
            totalWorkoutCount: 3,
            dateStart: sod(2026, 1, 1),
            dateEnd: sod(2026, 1, 7)
        )
        XCTAssertEqual(k.avgDurationOverallMin, 50)
    }

    func testAvgDurationLastVsPrior_docExample_delta15() {
        let ds = sod(2026, 3, 1)
        let de = sod(2026, 3, 7)
        var workouts: [ActivityWorkoutInput] = []
        for _ in 0..<2 {
            let day = sod(2026, 2, 25)
            workouts.append(ActivityWorkoutInput(date: day, startTime: noon(on: day).addingTimeInterval(Double(workouts.count)), durationMin: 45))
        }
        workouts.append(ActivityWorkoutInput(date: ds, startTime: noon(on: ds), durationMin: 50))
        workouts.append(ActivityWorkoutInput(date: sod(2026, 3, 2), startTime: noon(on: sod(2026, 3, 2)), durationMin: 70))
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: workouts,
            totalWorkoutCount: workouts.count,
            dateStart: ds,
            dateEnd: de
        )
        XCTAssertEqual(k.avgDurationLastNMin, 60)
        XCTAssertEqual(k.avgDurationPriorMin, 45)
        XCTAssertEqual(k.deltaDurationMin, 15)
    }

    func testAvgDurationRecentEmpty_priorOnly_deltaNegative48() {
        let ds = sod(2026, 3, 1)
        let de = sod(2026, 3, 7)
        var workouts: [ActivityWorkoutInput] = []
        for i in 0..<4 {
            let day = cal.date(byAdding: .day, value: i, to: sod(2026, 2, 24))!
            workouts.append(ActivityWorkoutInput(date: day, startTime: noon(on: day), durationMin: 48))
        }
        let k = ActivityKPIMath.computeWorkoutKPIs(
            workouts: workouts,
            totalWorkoutCount: workouts.count,
            dateStart: ds,
            dateEnd: de
        )
        XCTAssertEqual(k.workoutsLastN, 0)
        XCTAssertEqual(k.avgDurationLastNMin, 0)
        XCTAssertEqual(k.avgDurationPriorMin, 48)
        XCTAssertEqual(k.deltaDurationMin, -48)
    }

    // MARK: - §5 Muscle radar

    func testMuscleRadar_chestRatio_1_whenHitsWeeklyTargetOver7Days() {
        let ds = sod(2026, 4, 1)
        let de = sod(2026, 4, 7)
        var sets: [ActivitySetInput] = []
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: ds)!
            sets.append(ActivitySetInput(date: day, exerciseTitle: "Bench", setType: "normal", weightKg: 60, reps: 8))
        }
        let radar = ActivityKPIMath.computeMuscleRadar(
            sets,
            templateMap: ["Bench": "chest"],
            dateStart: ds,
            dateEnd: de,
            muscleTargets: ["Chest": 7]
        )
        XCTAssertEqual(radar.currentCounts["Chest"], 7)
        XCTAssertEqual(radar.currentRatios["Chest"]!, 1.0, accuracy: 1e-9)
        XCTAssertEqual(radar.daysUsed, 7)
    }

    func testMuscleRadar_legsRatio_0_75_docExample() {
        let ds = sod(2026, 4, 1)
        let de = sod(2026, 4, 14)
        var sets: [ActivitySetInput] = []
        for i in 0..<21 {
            let day = cal.date(byAdding: .day, value: i % 14, to: ds)!
            sets.append(ActivitySetInput(date: day, exerciseTitle: "Squat", setType: "normal", weightKg: 100, reps: 5))
        }
        let radar = ActivityKPIMath.computeMuscleRadar(
            sets,
            templateMap: ["Squat": "quadriceps"],
            dateStart: ds,
            dateEnd: de,
            muscleTargets: ["Legs": 14]
        )
        XCTAssertEqual(radar.currentRatios["Legs"]!, 0.75, accuracy: 1e-9)
        XCTAssertEqual(radar.daysUsed, 14)
    }

    // MARK: - §6 Volume progression % change

    func testVolumeProgression_chest_50pct_weekOverWeek() {
        let template = ["Press": "chest"]
        let monday = sod(2026, 5, 4)
        let nextMonday = cal.date(byAdding: .day, value: 7, to: monday)!
        let sets: [ActivitySetInput] = [
            ActivitySetInput(date: noon(on: monday), exerciseTitle: "Press", setType: "normal", weightKg: 100, reps: 8),
            ActivitySetInput(date: noon(on: nextMonday), exerciseTitle: "Press", setType: "normal", weightKg: 100, reps: 12),
        ]
        let de = cal.date(byAdding: .day, value: 1, to: nextMonday)!
        let vol = ActivityKPIMath.computeVolumeProgression(sets, templateMap: template, dateEnd: de)
        let chestIdx = vol.muscles.firstIndex(of: "Chest")!
        let pctRow = vol.pctChange[chestIdx]
        XCTAssertFalse(pctRow.isEmpty)
        XCTAssertEqual(pctRow.last!, 50, accuracy: 1e-9)
    }

    func testVolumeProgression_pctChange_specialCases_doc() {
        let template = ["R1": "lats", "R2": "biceps", "R3": "quadriceps"]
        let w0 = sod(2026, 6, 1)
        let w1 = cal.date(byAdding: .day, value: 7, to: w0)!
        let sets: [ActivitySetInput] = [
            ActivitySetInput(date: noon(on: w0), exerciseTitle: "R1", setType: "normal", weightKg: 100, reps: 0),
            ActivitySetInput(date: noon(on: w1), exerciseTitle: "R1", setType: "normal", weightKg: 100, reps: 8),
            ActivitySetInput(date: noon(on: w0), exerciseTitle: "R2", setType: "normal", weightKg: 100, reps: 4),
            ActivitySetInput(date: noon(on: w1), exerciseTitle: "R2", setType: "normal", weightKg: 100, reps: 0),
            ActivitySetInput(date: noon(on: w0), exerciseTitle: "R3", setType: "normal", weightKg: 100, reps: 2),
            ActivitySetInput(date: noon(on: w1), exerciseTitle: "R3", setType: "normal", weightKg: 100, reps: 5),
        ]
        let de = cal.date(byAdding: .day, value: 1, to: w1)!
        let vol = ActivityKPIMath.computeVolumeProgression(sets, templateMap: template, dateEnd: de)
        let backI = vol.muscles.firstIndex(of: "Back")!
        let biI = vol.muscles.firstIndex(of: "Biceps")!
        let legI = vol.muscles.firstIndex(of: "Legs")!
        XCTAssertEqual(vol.pctChange[backI].last!, 100)
        XCTAssertEqual(vol.pctChange[biI].last!, 0)
        XCTAssertEqual(vol.pctChange[legI].last!, 150)
    }

    // MARK: - §7 Activity KPIs

    func testActivityKPIs_stepsMean_truncatesTowardZero() {
        let rows = [
            row(sod(2026, 2, 1), steps: 9000, stand: 120, speed: 3.5),
            row(sod(2026, 2, 2), steps: 9000, stand: 120, speed: 3.5),
            row(sod(2026, 2, 3), steps: 12000, stand: 120, speed: 4.0),
        ]
        let k = ActivityKPIMath.computeActivityKPIs(rows, dateStart: sod(2026, 2, 1), dateEnd: sod(2026, 2, 3))
        XCTAssertEqual(k.avgSteps, 10_000)
        XCTAssertEqual(k.priorDays, 3)
    }

    func testActivityKPIs_stand_roundsOneDecimal() {
        let rows = [
            row(sod(2026, 2, 1), steps: 0, stand: 100.25, speed: nil),
            row(sod(2026, 2, 2), steps: 0, stand: 100.35, speed: nil),
        ]
        let k = ActivityKPIMath.computeActivityKPIs(rows, dateStart: sod(2026, 2, 1), dateEnd: sod(2026, 2, 2))
        XCTAssertEqual(k.avgStandMin, 100.3, accuracy: 1e-9)
    }

    func testActivityKPIs_walkSpeed_skipsNil_days() {
        let rows = [
            row(sod(2026, 2, 1), steps: 0, stand: 0, speed: nil),
            row(sod(2026, 2, 2), steps: 0, stand: 0, speed: 3.333),
            row(sod(2026, 2, 3), steps: 0, stand: 0, speed: 3.337),
            row(sod(2026, 2, 4), steps: 0, stand: 0, speed: nil),
            row(sod(2026, 2, 5), steps: 0, stand: 0, speed: nil),
        ]
        let k = ActivityKPIMath.computeActivityKPIs(rows, dateStart: sod(2026, 2, 1), dateEnd: sod(2026, 2, 5))
        XCTAssertEqual(k.avgWalkingSpeed, 3.34, accuracy: 1e-9)
    }

    // MARK: - §8 Energy TDEE

    func testEnergyTDEE_qualityFilter_dropsLowBasalOrLowActive() {
        let rows = [
            row(sod(2026, 3, 1), steps: 0, stand: 0, speed: nil, basal: 1500, active: 400),
            row(sod(2026, 3, 2), steps: 0, stand: 0, speed: nil, basal: 900, active: 400),
            row(sod(2026, 3, 3), steps: 0, stand: 0, speed: nil, basal: 1200, active: 40),
        ]
        let e = ActivityKPIMath.computeEnergyTDEE(rows, dateStart: sod(2026, 3, 1), dateEnd: sod(2026, 3, 3))
        XCTAssertEqual(e.points.count, 1)
        XCTAssertEqual(e.points[0].activeKcal, 400)
    }

    func testEnergyTDEE_sevenEqualActives_centeredRolling500() {
        let rows = (0..<7).map { i in
            row(
                cal.date(byAdding: .day, value: i, to: sod(2026, 4, 1))!,
                steps: 0, stand: 0, speed: nil,
                basal: 1500, active: 500
            )
        }
        let e = ActivityKPIMath.computeEnergyTDEE(rows, dateStart: sod(2026, 4, 1), dateEnd: sod(2026, 4, 7))
        XCTAssertEqual(e.effectiveDays, 7)
        for p in e.points {
            XCTAssertEqual(p.activeKcal7d!, 500, accuracy: 1e-9)
            XCTAssertEqual(p.tdee!, 2000, accuracy: 1e-9)
        }
    }

    func testEnergyTDEE_fivePointRamp_matchesCenteredRollingGolden() {
        let base = sod(2026, 4, 1)
        let actives = [200.0, 400, 600, 800, 1000]
        let rows = actives.enumerated().map { i, a in
            row(cal.date(byAdding: .day, value: i, to: base)!, steps: 0, stand: 0, speed: nil, basal: 1200, active: a)
        }
        let e = ActivityKPIMath.computeEnergyTDEE(rows, dateStart: base, dateEnd: cal.date(byAdding: .day, value: 4, to: base)!)
        XCTAssertEqual(e.effectiveDays, 5)
        let rolling = NutritionKPIMath.centeredRollingMean(actives, window: 7)
        for i in 0..<e.points.count {
            guard let actual = e.points[i].activeKcal7d, let raw = rolling[i] else {
                XCTFail("missing rolling at index \(i)")
                continue
            }
            let expRounded = (raw * 10).rounded() / 10
            XCTAssertEqual(actual, expRounded, accuracy: 1e-9, "index \(i)")
        }
    }

    // MARK: - Helpers

    private func row(
        _ date: Date,
        steps: Double,
        stand: Double,
        speed: Double?,
        basal: Double = 1200,
        active: Double = 300
    ) -> HealthRecordStore.ActivityDailyRow {
        HealthRecordStore.ActivityDailyRow(
            date: date,
            activeEnergyKcal: active,
            basalEnergyKcal: basal,
            steps: steps,
            exerciseMin: 0,
            standMin: stand,
            walkingSpeedKmh: speed,
            daylightMin: 0
        )
    }
}
