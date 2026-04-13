import Foundation

// Mirrors health/app/shared/chart_descriptions.py (lines 249–478) and
// health/app/shared/globals.py — verbatim content, 0 deviation.

// MARK: - VO2 Reference Values (mirrors VO2_REFS in globals.py)

struct VO2Refs {
    let below: Double
    let average: Double
    let elite: Double
}

enum HeartConstants {
    static let vo2LongevityGoal: Double = 52.0

    static let vo2Refs: [String: VO2Refs] = [
        "20-29": VO2Refs(below: 38, average: 47, elite: 55),
        "30-39": VO2Refs(below: 34, average: 43, elite: 52),
        "40-49": VO2Refs(below: 30, average: 39, elite: 50),
        "50-59": VO2Refs(below: 25, average: 35, elite: 45),
    ]

    static func vo2Refs(forAge age: Int) -> (refs: VO2Refs, ageLabel: String) {
        if age < 30 { return (vo2Refs["20-29"]!, "20–29") }
        if age < 40 { return (vo2Refs["30-39"]!, "30–39") }
        if age < 50 { return (vo2Refs["40-49"]!, "40–49") }
        return (vo2Refs["50-59"]!, "50–59")
    }
}

// MARK: - Description Strings

enum HeartDescriptions {

    static let hrvTrend = """
**Heart Rate Variability (HRV)** measures the variation in time between consecutive heartbeats (in milliseconds). Higher HRV = better autonomic nervous system balance = better recovery.

**How baseline & SD are calculated:**
- **Baseline** = 30-day rolling mean of your daily HRV.
- **SD** = 30-day rolling standard deviation
- Together they form your personal normal range — deviations from it are what matter, not the absolute number

**Dot colours (SD-based — personalised to your HRV):**
| Condition | Meaning |
|---|---|
| Within or above baseline ± 1 SD | Good recovery / normal condition |
| Between -1 SD and -2 SD | Body under stress, consider recovery |
| Below -2 SD | Definite recovery needed |

**HRV Trends:**
| Trend | Meaning |
|---|---|
| Rising trend (2–4 weeks) | Positive training stimulus, good adaptation — the body is building capacity. This is the goal in a structured training phase |
| Stable trend (horizontal) | Body in balance between load and recovery. Good as a steady state, but also signals no new stimulus is being applied |
| Slight downward trend (1–2 weeks) | Normal response to an intense training phase (overreach). No alarm — typically followed by a rebound after a deload. |
| Strong downward trend (>2–3 weeks, no rebound) | Warning signal: overtraining, chronic sleep deprivation, illness, too aggressive a calorie deficit, or psychological stress. Intervention required |

**What's important**
- If the 7-day rolling HRV sits above baseline that's a good sign; below baseline means no itensity this day
- Avoid 3+ convecutive days below baseline signals (accumulates fatigue or approaching illness)
- When 30-day trend slopes downward, schedule a 5–7 day deload week

> Note: 30-day and 7-day rolling means are calculated based on the selected date range.
"""

    static let hrvHistogram = """
**HRV Distribution** shows the spread of your daily HRV readings over the selected period.

**What the shape tells you:**
| Shape | Meaning |
|---|---|
| Bell curve centred high | Consistently well-recovered |
| Bell curve centred low | Chronically under-recovered |
| Skewed left (long left tail) | Occasional stress spikes pulling the average down |
| Very wide spread | High day-to-day variability — lifestyle or training inconsistency |

**Shaded zones match the trend chart:**
| Condition | Meaning |
|---|---|
| Within or above baseline ± 1 SD | Good recovery / normal condition |
| Between -1 SD and -2 SD | Body under stress, consider recovery |
| Below -2 SD | Definite recovery needed |

**What important:**
- Shift your HRV distribution rightward — when the bulk of the blue bars sits left of the yellow median line, you're chronically under-recovered; aim to move the peak toward/above your personal baseline
- Monitor if the green tail (>median+1SD) grows or shrinks — expanding high-HRV days indicate improving recovery capacity; shrinking high end signals declining stress resilience
"""

    static let rhrTrend = """
**Resting Heart Rate (RHR)** is the number of times your heart beats per minute at rest. Unlike HRV, a **lower RHR is better** — it indicates a stronger, more efficient heart.

**How baseline & SD are calculated:**
- **Baseline** = 30-day rolling mean of your daily RHR
- **SD** = 30-day rolling standard deviation
- An elevated RHR above your personal baseline is often the earliest sign of illness, overtraining, or poor sleep — even before you feel it

**Dot colours (SD-based — personalised to your RHR):**
| Condition | Meaning |
|---|---|
| Within or below baseline ± 1 SD | Normal / well-recovered |
| Between +1 SD and +2 SD above baseline | Elevated — mild stress or fatigue |
| Above +2 SD | Significantly elevated — recovery needed |

**RHR benchmarks:**
| Level | RHR |
|---|---|
| Elite athletes | 40–50 bpm |
| Active adults | 50–60 bpm |
| Average | 60–70 bpm |
| Elevated | > 70 bpm |

**What's important**
- When 7-day RHR rolling line rises above baseline, reduce training volume by 30–50% until it returns to normal
- Avoid 3+ consecutive days above baseline — immediately add 1 rest day and audit sleep/stress before fatigue compounds

> Note: 30-day and 7-day rolling means are calculated based on the selected date range.
"""

    static let hrvRhr = """
**HRV + Resting Heart Rate** are the two most reliable daily recovery markers. They move in **opposite directions** when your body is well-recovered:

- **Good recovery:** HRV ↑ and RHR ↓
- **Under-recovered:** HRV ↓ and RHR ↑

**What to look for:**
| Signal | Meaning |
|---|---|
| HRV rising + RHR falling | Adaptation — fitness improving |
| HRV stable + RHR stable | Maintenance — load and recovery balanced |
| HRV falling + RHR rising | Accumulating fatigue — reduce load |
| HRV very low + RHR very high | Possible illness or overtraining |

**What's important:**
- When RHR line rises while HRV drops, simultaneously, cut training intensity
- When RHR line rises while HRV rises, investigate external stressors 
- When RHR line drops while HRV drops, you're metabolically fatigued from prolonged deficit
- When RHR line drops while HRV rises, perfect recovery state
- When RHR line and HRV stable, maintain current program
"""

    static func vo2Trend(ageLabel: String, belowAvg: Double, avgUpper: Double, elite: Double) -> String {
        """
**VO2 Max** is the maximum rate at which your body can consume oxygen during exercise. It is one of the strongest single predictors of long-term health and all-cause mortality.

Reference values shown are personalised to **age group \(ageLabel)**:
| Category | VO₂ Max |
|---|---|
| Below average | < \(Int(belowAvg)) ml/kg/min |
| Average | \(Int(belowAvg))–\(Int(avgUpper)) ml/kg/min |
| Above average | \(Int(avgUpper))–\(Int(elite)) ml/kg/min |
| Elite / Longevity goal | ≥ \(Int(elite)) ml/kg/min |

**How the metrics are calculated:**
- The current 14-day rolling VO2 (dashed line) is calculated (a) based on the selected date range and (b) based on a 14-day rolling average (if you select less than 14 days, the rolling average will be shorter)).
- The baselines metric (a) uses data from the max of your earliest date or 30 days before the end date, up to the end date—for short selections (≤30 days), it grabs a full 30-day window; for longer ones, it starts at your selection's start and (b) are calculated based on a 30-day rolling average

**Notes:**
- The **14-day rolling average** best represents your true latest trend
- The **30-day rolling baseline** represents your long term trend
- VO₂ Max improves with consistent aerobic training over weeks and months, not days
- Each +1 ml/kg/min is associated with a ~2–3% reduction in cardiovascular mortality risk

**What's important:**
- When 14-day average plateaus or declines during bulk/cut, add 10–15 min Zone 2 cardio 3x/week to drive cardiovascular adaptation

> Note: Select at least 14 days.
"""
    }

    static let vo2Weight = """
**VO₂ Max is expressed per kilogram of body weight** (ml/kg/min). This means losing weight *mechanically* raises your VO₂ Max — even without any fitness change.

This chart separates the two effects:

| Metric | What it measures |
|---|---|
| **VO₂ Max (ml/kg/min)** | Weight-adjusted — the Apple Health value |
| **Absolute VO₂ (ml/min)** | Raw cardio capacity — weight-independent |
| **Body Weight (kg)** | Reference for the mechanical effect |

**How to read it:**
| Pattern | Meaning |
|---|---|
| Both VO₂ lines rise | Genuine fitness improvement |
| Only VO₂ Max rises, Absolute VO₂ flat | Weight loss inflating the score — not fitness |
| Absolute VO₂ rises, VO₂ Max flat | Fitness improving, weight also increasing |
| Both lines fall | Detraining or significant weight gain |

**What's important:**
- Prioritize both relative VO₂ and absolute VO₂ rising together — this is true cardiovascular adaptation; anything less is bodyweight math masquerading as fitness gains
- When relative VO₂ spikes without absolute VO₂ support, ignore it as a training signal — it's just fat loss temporarily boosting your per-kg score
- Focus on **Absolute VO₂ trend** to judge true cardiovascular improvement.

> Note: Select at least 14 days.
"""

    static let recoveryKPI = """
**Recovery metrics** display the most important metrics with respect to recovery

- **Recovery score:** A 0-100 score blending standardized HRV and RHR deviations from baselines. Higher means better recovery and adaptability to stress.
- **HRV vs Baseline (30D):** Compares your recent 7-day average HRV (today's value) to your long-term baseline (30-day rolling average). Higher HRV indicates superior parasympathetic recovery; aim for positive values.
- **RHR vs Baseline (30D):** Compares your recent 7-day average RHR (today's value) to your long-term baseline (30-day rolling average). Lower RHR reflects better cardiovascular recovery; aim for negative values.
    - **Divergence:** HRV z-score minus RHR z-score (HRV↑ RHR↓ = positive). Measures recovery-fitness alignment
    
**How the metrics are calculated**
- The baselines metrics (30D; HRV and RHR) (a) use data from the max of your earliest date or 30 days before the end date, up to the end date—for short selections (≤30 days), it grabs a full 30-day window; for longer ones, it starts at your selection's start and (b) are calculated based on a 30-day rolling average
- The current metrics are calculated (a) based on the selected date range and (b) based on a 7-day rolling average (if you select less than 7 days, the rolling average will be shorter)

**What's important:**
- A recovery score > 50
- HRV as least as good as the baseline (the higher compared to the baseline, the better)
- RHR as least as good as the baseline (the lower compared to baseline, the better)
- HRV / RHR Signal: Aligned
"""

    static let fitnessKPI = """
**Fitness metrics** track cardiovascular performance and training adaptation trends.

- **VO2 Max (Last):** Your latest estimated maximal oxygen uptake (ml/kg/min) from recent measurements. Higher values indicate superior aerobic capacity and endurance
- **VO2 Max (14D AVG) vs Baseline (30D):** Change in average VO2 over the past 30 days versus current (14-day rolling average) (positive = improving fitness; negative = potential detraining).

**How the metrics are calculated**
- The baselines metric (a) uses data from the max of your earliest date or 30 days before the end date, up to the end date—for short selections (≤30 days), it grabs a full 30-day window; for longer ones, it starts at your selection's start and (b) are calculated based on a 30-day rolling average
- The current 14-day rolling VO2 metric are calculated (a) based on the selected date range and (b) based on a 14-day rolling average (if you select less than 14 days, the rolling average will be shorter))

**What's important:**
- VO2 current >45 ml/kg/min
- Positive VO2 delta 30D (>0) for gains.
"""

    static let hrvVsTrainingVolume = """
**HRV vs Training Volumne:** Shows your HRV vs the training volumne (from 1-2 days prior)

**How to read this chart**
- The **cyan line** shows your 7-day rolling average HRV — the main signal to watch
- **Faint dots** are raw daily HRV readings, showing day-to-day variability
- **Background bars** show training volume from 1–2 days prior.
    - Example: Training Jan 12: 5000kg Training Jan 13: 3000kg -> Jan 13 (Lag 1; the bar): 5000kg, Jan 14 (Lag2; the bar): 5000kg, Jan 15 (Lag1; the bar): 3000kg

**How volume is calculated**
- Volume = **weight × reps** summed across all sets for a given day

**What to look for**
- HRV typically **dips 1–2 days after** a heavy session, then recovers
- If HRV stays suppressed for 3+ days after training, recovery may be insufficient
- A rising HRV trend alongside consistent training = positive adaptation

**What's important:**
- When HRV stays flat despite volume increases, you're adapted — safe to push 5–10% more weekly volume on lagging muscle groups
- When HRV rises after volume spikes, double down on that training block — it's your personal sweet spot for progressive overload
"""

    static let hrvPerformance = """
**HRV vs Performance:** Shows your HRV vs the performance (weight x reps from the day of the workout)

**How to read this chart**
- Each dot is a **single workout session**, plotted by your HRV that morning vs. total volume lifted
- The **regression line** shows your personal HRV → performance trend
- The **vertical zone lines** are your personal readiness thresholds, derived from your HRV distribution

**What to look for**
- The expectation is that on high HRV days, performance should be better
- A positive slope (in regression line) means HRV is a reliable predictor of your output
- A flat slope means other factors (sleep, motivation, nutrition) dominate
- Use your green zone threshold as a signal to attempt PRs or push intensity

**How volume is calculated**
- Volume = **weight × reps** summed across all sets in a session
- HRV = earliest Apple Watch reading on the day of the workout

**What's important:**
- Low HRV days (< baseline -1SD) showing highest volume dots — never train max effort on these
- High HRV days (> baseline +1SD) with low volume dots — push extra
- When low HRV consistently correlates with >13.5kg volume, reduce baseline weekly volume by 20% — that's your personal unsustainable threshold
- Use quadrant medians as session planning guide — pick volume target matching your morning HRV reading for optimal performance/recovery balance
"""
}
