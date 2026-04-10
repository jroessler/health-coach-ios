import Foundation

// Mirrors health/app/shared/chart_descriptions.py — nutrition-related descriptions only.

enum NutritionDescriptions {

    static let dailyCaloriesMacros = """
        **Daily Calories + Macros** tracks your caloric intake and macronutrient distribution over time.

        **How to read the chart:**
        - Each bar represents one day — stacked into **Protein**, **Carbs**, and **Fat** contributions
        - The **yellow line** is a 7-day rolling average, smoothing out daily fluctuations to show your true trend (if you select less than 7 days, the rolling average will be shorter)

        **What's important**
        - 7-day rolling average trend — is it drifting up, down, or flat? This reveals your actual dietary direction
        - Consistency of the protein layer (blue) — it should be large and stable every single day, including low-calorie days; protein collapsing on low days signals muscle-loss risk
        """

    static let macroStackedBars = """
        **Macros** tracks your macronutrient distribution.

        **How to read the chart:**
        - Show your period average vs target — green means on track, amber means close, red means off target (±10%).

        **Target distribution (High Protein · Balanced Carb · Low Fat):**
        - Protein — 35%
        - Carbs — 40%
        - Fat — 25%

        **What's important**
        - Meeting the target distribution of protein, carbs, and fat
        """

    static let calorieIntakeVsTDEE = """
        **Calorie Intake vs TDEE** shows your daily calorie intake vs daily calorie expenditure (Total Daily Energy Expenditure; TDEE).
        A value of `-300` means you were 300 kcal under your TDEE — i.e. in a 300 kcal deficit.

        **Two balance lines are shown:**
        - **Balance vs Apple TDEE** — TDEE estimated by Apple. You can see raw values (raw) and 7-day rolling avererage (7-day rolling average; if you select less than 7 days, the rolling average will be shorter)
        - **Balance vs Empirical TDEE** — TDEE estimated by empirical calculation (14-day rolling back-calculation from weight change, more accurate long-term; if you select less than 14 days, the method is still trying to use a rolling window of at least 14 days)

        **Targets for a clean cut:**

        | Zone | Daily Balance | Weekly Effect |
        | --- | --- | --- |
        | Dangerous cut | -700 to -500 kcal | ~0.5–0.7 kg/wk loss |
        | Moderate cut | -500 to -300 kcal | ~0.3–0.5 kg/wk loss |
        | Maintenance | -100 to +100 kcal | Weight stable |
        | Surplus | > +200 kcal | Weight gain |

        > Don't focus on individual days.

        **What's important:**
        - When trying to loose fat, the calorie deficit should stay in the moderate cut zone. Avoid other zones
        - When trying to loose fat, avoid staying in the dangerous cut zone for too long
        - When Apple TDEE and Empirical TDEE diverge, trust Empirlca TDEE more
        """

    static let weightDualAxis = """
        **Weight & Body Fat Trends** tracks your body composition progress over time using two synced axes.

        **How to read the chart:**
        - **Weight 7d Avg** — 7-day rolling weight average (if you select less than 7 days, the rolling average will be shorter)
        - **Fat Free Muscle mass (FFM) 7d Avg** — 7-day rolling fat-free mass (`FFM = weight × (1 - body fat%)`) average (if you select less than 7 days, the rolling average will be shorter)
        - **Body Fat 7d Avg** — 7-day rolling body fat average (if you select less than 7 days, the rolling average will be shorter)

        **What to look for (bodybuilding recomposition):**

        | Signal | Meaning |
        | --- | --- |
        | Weight ↓ + Body Fat ↓ + FFM stable | Clean fat loss |
        | Weight ↓ + FFM ↓ | Possible muscle loss |
        | Weight stable + Body Fat ↓ + FFM ↑ | Ideal recomposition |

        **What's important**
        - The gap between weight and FFM — this gap represents your total fat mass in kg; it should be shrinking during a cut while the FFM holds flat
        - FFM direction is the most critical signal — flat or rising = muscle preserved; declining green
        - flattening of the body fat — when body fat stops dropping despite a continued calorie deficit, it usually signals metabolic adaptation; time to reassess calories or add a refeed week
        """

    static let weightLossRates = """
        **Weekly Loss Rates** shows how much weight and body fat you're losing week-over-week.

        **Target guidelines for bodybuilding cuts:**

        | Metric | Target | Reasoning |
        | --- | --- | --- |
        | Weight loss | -0.5 kg/wk | Fast enough to lose fat, slow enough to preserve muscle |
        | Body fat loss | -0.25 %/wk | Sustainable rate that minimises muscle catabolism |

        **What's important**
        - Losses consistently below the −0.5kg/wk dashed line — weeks where weight loss significantly overshoots the target are dangerous zones
        - Losses consistently close to the −0.25%/wk dashed line — ideal; more muscle-protective signal
        - When trying to loose weight: Positive bars (weight gain weeks) — a single positive week is fine and can indicate a successful refeed; two or more consecutive positive bars during a cut means the deficit has been lost entirely
        """

    static func preWorkoutNutritionTiming(avgWeightKg: Double) -> String {
        let proteinTarget = Int(avgWeightKg * 0.3)
        let carbsTarget = Int(avgWeightKg * 0.5)
        return """
            **Pre-Workout Nutrition Timing** shows what you ate in the 2-hour window before each workout — how far out you ate, and how much protein and carbs you consumed.

            **Evidence-based recommendations (based on your avg weight: \(String(format: "%.1f", avgWeightKg))kg):**
            - Eat **1–2 hours before training** for optimal digestion and energy availability
            - Target **~\(proteinTarget)g protein** (~0.3g/kg bodyweight)
            - Target **~\(carbsTarget)g carbs** (~0.5g/kg bodyweight)
            - **Fasted training** (0g eaten) is also healthy and effective — especially for morning sessions

            **How to read the chart:**
            - Each dot = one workout session, X = minutes before workout, Y = protein consumed
            - Dot size = carbs consumed
            - **Green** = eaten 60–120 min before (optimal window)
            - **Amber** = eaten within 60 min (may cause discomfort) or fasted
            - **Red** = eaten more than 120 min before (may be too early)
            - The shaded band marks the **60–120 min optimal window**

            **What's important:**
            - Most dots should fall inside the green optimal window (60–120 min band)
            - Dots above the blue dashed line mean adequate pre-workout protein was consumed
            - Large dots indicate good carb availability for training energy
            - The "sweet spot" — dots that are green, above the protein line, AND large — these are your best-fuelled sessions; compare those workouts to performance data to validate the impact
            """
    }

    static let postWorkoutNutritionTiming = """
        **Post-Workout Protein Timing** shows how many minutes after each workout you consumed your first meal, and how much protein it contained.

        **Evidence-based recommendation:**
        - Consume **≥40g of high-quality protein within 1–2 hours** after training
        - High-quality sources: whey, eggs, chicken, fish, Greek yogurt
        - This window maximises muscle protein synthesis (MPS) triggered by the workout stimulus

        **Quadrants:**

        |  | ≤ 120 min | > 120 min |
        | --- | --- | --- |
        | **≥ 40g protein** | Optimal — timing & amount both good | Good amount, too late |
        | **< 40g protein** | On time, not enough protein | Too late & too little |

        **What's important:**
        - Green dots above 40g and within 120 min are optimal
        - Orange dots below the 40g line - these are the most actionable misses; you hit the timing window but left MPS under-stimulated
        - Dots beyond the 120 min dashed line
        """
}
