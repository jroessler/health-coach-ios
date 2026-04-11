import Foundation

// Mirrors health/app/shared/chart_descriptions.py — activity & workout descriptions only.

enum ActivityDescriptions {

    static func muscleRadar(daysUsed: Int) -> String {
        """
        **Muscle Group Distribution vs Targets** shows how well your training volume across the last **\(daysUsed)d** matches your **per-muscle weekly set targets**.

        **What's important**
        - A **round, symmetric shape** means each muscle group is close to its own target (good balance across the body)
        - Dents toward the centre show **under-trained** muscle groups relative to their targets; spikes outward show **over-trained** ones
        - Larger muscles (legs, back, chest) usually have higher weekly targets than smaller ones (biceps, triceps, shoulders, abs) — but on this radar they all sit at the same radius when they are **on target**
        """
    }

    static let volumeProgression = """
        **Week-over-Week Volume Progression** shows how your training volume for each muscle group changed relative to the previous week — making overload, deloads, and neglected groups immediately visible.

        **How to read this chart**
        - Each cell shows the **volume change vs the previous week** for a given muscle group
        - volume > 0 more volume than last week (progressive overload)
        - volume < 0 less volume than last week (deload or missed sessions)
        - volume = 0 roughly the same volume as last week

        **How volume is calculated**
        - Volume = **weight × reps** summed across all sets for that muscle group in a week

        **What's important:**
        - A row that alternates positive and negative numbers repeatedly signals inconsistent training frequency; you want mostly neutral to positive numbers with occasional planned negative deload weeks
        - A mostly negative column = low training week overall (illness, travel, life stress); a mostly positive column = high output week; this gives you an at-a-glance read on training consistency
        - Two or more negative weeks in a row for a muscle group means it's been significantly under-stimulated; hypertrophy requires consistent stimulus and this pattern is where gains stall

        > Note: Visualization *always* shows the last 6 weeks depending on user's selected end date!
        """

    static let energyTDEE = """
        **Daily Energy Burn** shows the two components of your TDEE stacked together.

        | Metric | What it is |
        |---|---|
        | **Basal (BMR)** | Calories burned at complete rest — organs, brain, thermoregulation. Driven by body mass and composition |
        | **Active Energy** | Calories from all movement — workouts, steps, and NEAT (non-exercise activity like walking and standing) |
        | **TDEE** | Total Daily Energy Expenditure with 7 day rolling average (if you select less than 7 days, the rolling average will be shorter) |

        **What's important:**
        - Height of the orange active bars vs. the green target line — tells you at a glance whether you're consistently hitting your daily movement / activity goal.
        - If TDEE is consistently low on rest days, consider increasing walking or general activity to maintain a higher baseline burn
        """
}
