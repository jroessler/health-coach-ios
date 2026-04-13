# Nutrition page — how each number is computed

This document describes the **pure math** behind the Nutrition screen (`NutritionComputer`, `NutritionKPIMath`, `NutritionConstants`). The chart date range uses **start-of-day** bounds from the picker (`NutritionView`), aligned with the app’s **ISO-8601** calendar (`Calendar(identifier: .iso8601)` in code) unless noted.

Daily nutrition aggregates come from **SwiftData** `NutritionEntry` (summed by calendar day). Scale and Apple TDEE come from **GRDB** (`HealthRecordStore`). Workout windows use **Hevy** `Workout` times from SwiftData.

---

## 1. Daily macro aggregates (before KPIs)

**Definition**  
**What:** One row per **calendar day** with totals for energy (kcal), protein (g), carbs (g), fat (g).  
**How:** All `NutritionEntry` rows with a parsable `yyyy-MM-dd` `date` are grouped by that local day; numeric fields are **summed** (`loadMacros`).

**Example 1**  
- **Toy inputs:** Two entries on **2026-01-10**: 800 kcal and 400 kcal.  
- **Expected output:** That day’s row has **1200** kcal (and summed macros).

---

## 2. Range filter — which days enter the KPI / chart pipeline

**Definition**  
**What:** Only days in **`[dateStart, dateEnd]`** with **total calories ≥ 500** (`minCaloriesForFiltering`) are kept for `computeMacroPct` and downstream charts/KPIs that consume **filtered** macros.  
**How:** `NutritionKPIMath.filterMacros` — days below 500 kcal are **excluded** entirely (mirrors Python `filter_macros`).

**Example 1**  
- **Toy inputs:** A day with **499** kcal inside the range.  
- **Expected output:** That day does **not** appear in filtered series; rolling means skip it as if it were missing.

**Example 2**  
- **Toy inputs:** A day with **500** kcal.  
- **Expected output:** Included.

---

## 3. Macro percentages (per day)

**Definition**  
**What:** After filtering (§2), each day gets **protein / carbs / fat % of calories**, from **Atwater** factors: protein **4**, carbs **4**, fat **9** kcal/g.  
**How:** If `calories > 0`:  
- `protPct = round((proteinG × 4 / calories × 100), 1)`  
- same pattern for carbs and fat.  
If `calories == 0`, percentages stay **nil**.

**Example 1**  
- **Toy inputs:** 2000 kcal, 150 g protein → protein kcal = 600 → **30.0%**.  
- **Expected output:** `protPct = 30.0` (1 decimal).

---

## 4. KPI cards — Last 7d average calories & protein

**Definition**  
**What:** **Average daily calories** and **average daily protein (g)** over the **last up to 7 calendar days** that lie in the chart range **and** pass the filter (§2).  
**How:**  
- `last7Start = max(dateStart, dateEnd − 6 days)` (inclusive 7-day window ending on `dateEnd`).  
- `last7` = filtered macro rows with `date` in `[last7Start, dateEnd]`.  
- `last7dAvgKcal` = arithmetic mean of `calories` over `last7` (**0** if empty).  
- Same for average protein (g) — used for protein/kg (§5).

**Example 1**  
- **Toy inputs:** Three filtered days in the window: 2000, 2200, 1800 kcal.  
- **Expected output:** **2000** kcal average (for the card’s calorie line as implemented).

---

## 5. KPI cards — Protein per kg body weight

**Definition**  
**What:** **7-day average protein (g)** divided by a **single body-weight value** (kg).  
**How:** Weight = **latest weigh-in with non-nil `weightKg` in the chart range**, else **latest weigh-in before `dateStart`** (still with weight). If no weight anywhere → **`nil`**. If weight ≤ 0 → **`nil`**. Otherwise:  
`sevenDayProteinPerKg = round((avgProtein7d / weight) × 100) / 100` (2 decimals).

**Example 1**  
- **Toy inputs:** Avg protein **120 g** / 7d; latest weight in range **80 kg**.  
- **Expected output:** **1.5** g/kg (illustrative).

**Example 2**  
- **Toy inputs:** No scale data.  
- **Expected output:** **`nil`** (N/A in UI).

---

## 6. KPI cards — Total weight & body fat change (in range)

**Definition**  
**What:** **Weight change** = last **in-range** weigh-in minus first **in-range** weigh-in (kg), **rounded to 1 decimal**, only if **≥ 2** weigh-ins with weight in range.  
**Body fat change** = last minus first among in-range rows where **`fatPercent` is non-nil**, same rounding, only if **≥ 2** such rows.  
**How:** `computeKPIValues` on filtered scale rows (`date` in `[dateStart, dateEnd]`, sorted ascending).

**Example 1**  
- **Toy inputs:** First weight **80.0**, last **79.2** kg in range.  
- **Expected output:** **−0.8** kg.

---

## 7. Macro target distribution (overview bars)

**Definition**  
**What:** **Unweighted** arithmetic mean of **daily** `protPct`, `carbPct`, `fatPct` across **all filtered days** in the range (each day counts once). Missing pct for a macro on a day is skipped via `compactMap`.  
**How:** `computeMacroPctAverages` — if no values for a macro, that average is **nil**.

**Example 1**  
- **Toy inputs:** Two days: protein **30%** and **40%**.  
- **Expected output:** **35%** average protein (illustrative).

---

## 8. Daily Calories + Macros chart

### Daily values

**Definition**  
**What:** One point per **filtered** day, sorted by date. **Calories** = daily total; macro **kcal** = `calories × (pct / 100)` using rounded percents from §3.  
**How:** `prepareDailyCaloriesMacrosData`.

### Rolling average calories (line)

**Definition**  
**What:** **`rollingAvgKcal`** = **centered** rolling mean of the **ordered list of daily calories** (only **consecutive filtered days** — **not** calendar gaps). Window = **7** (`rollingWindowDays`), **`min_periods = 1`**. Same rule as Activity TDEE rolling: `halfBefore = (7−1)/2`, `halfAfter = 7/2`, mean of available slice.  
**How:** `NutritionKPIMath.centeredRollingMean`.  
**Legend `effectiveDays`:** `min(number of points, 7)`.

**Example 1**  
- **Toy inputs:** Seven identical daily calories **2000**.  
- **Expected output:** Rolling line **2000** at each index once the window fills.

---

## 9. Calorie balance chart (Apple TDEE & empirical TDEE)

### Dates on the chart

**Definition**  
**What:** Union of **days that have intake** and **days that have Apple TDEE**, intersected with **`[dateStart, dateEnd]`**, sorted. No point is synthesized for a day that has neither (union can be sparse).  
**How:** `computeCalorieBalance` in `NutritionKPIMath`.

### Raw daily balance (Apple)

**Definition**  
**What:** For each chart day: **`intakeKcal − appleTDEE`** (both must exist that day), **rounded to integer** (`rounded()`). If either missing → **nil** for that day’s raw Apple balance.

### Empirical TDEE series (lookback + rolling intake + weight slope)

**Definition — lookback:**  
`numberOfDays = dateComponents(.day, from: dateStart, to: dateEnd).day + 1` (inclusive span).  
`lookbackWindow = min(max(numberOfDays, 14), 30)`.  
`lookbackStart = max(minDate, dateStart − lookbackWindow)` where **`minDate`** is the **earliest nutrition day in the app** (from all entries).  

**Intake alignment:** Build **`intakeFull`**: all intake rows from **`lookbackStart`…`dateEnd`** sorted by date (one value per day as loaded).  

**Weight at each intake day:** **Nearest** scale `weightKg` by **minimum absolute date distance** (`nearestValue`) among scale rows in the same extended window.

**14-day rate of weight change (kg/day):** For index **`i ≥ 14`**, if weights exist at **`i`** and **`i − 14`**:  
`deltaKgPerDay[i] = (w[i] − w[i−14]) / 14`. Otherwise **nil**.

**14-day average intake:** Left-aligned **rolling mean** with **window 14**, **`min_periods = 7`** (`empiricalRollingWindowDays / 2`).

**Empirical TDEE per intake row:**  
`empiricalTDEE[i] = intake14dAvg[i] − (deltaKgPerDay[i] ?? 0) × 7700`  
(`kcalPerKgBodyWeight` — same constant as legacy Python: energy content of 1 kg body mass).

**Fill:** Forward-fill then backward-fill (`ffillBfill`) on the empirical series so gaps interpolate. Values are mapped back to **chart days** in range; **ffill/bfill** again on the range-aligned series.

**Raw empirical balance:** **`intake − empiricalTDEE`** (rounded) per day when both exist.

### 7-day centered lines

**Definition**  
**What:** **`balanceApple7d`** and **`balanceEmpirical7d`** = **centered rolling mean** over the **optional** raw balance arrays (**nils skipped** inside each window), window **7** (`rollingWindowDays`). Values **rounded** for display.  
**How:** `centeredRollingMeanOptional`. **`effectiveDays`** = `min(chart day count, 7)`.

**Example 1**  
- **Toy inputs:** Constant intake = TDEE every day → raw balances **0** → rolling **0**.

---

## 10. Weight & body fat trends chart

**Definition**  
**What:** Scale rows in **`[dateStart, dateEnd]`**, sorted. For each day:  
- **weightRolling7d** — centered **7-day** rolling mean of **weight** (optional; skips nil weights in window).  
- **fatPctRolling7d** — same for **body fat %**.  
- **ffmRolling7d** — same for **fat-free mass (kg)** computed as `weightKg × (1 − fatPercent/100)` when **both** weight and fat exist that day; otherwise **nil** for that day before rolling.  
**How:** `computeScaleMetrics` + `centeredRollingMeanOptional`. **effectiveDays** = `min(row count, 7)`.

**Example 1**  
- **Toy inputs:** Weight flat **80 kg**, fat **20%** → FFM **64 kg** each day → rolling curves match when windows full.

---

## 11. Weekly loss rates chart

**Definition**  
**What:** Group all **in-range** scale days by **ISO week** (Monday start, `mondayOfWeek`). For each week: **mean weight** (kg, 2 dp) and **mean body fat %** if any BF values exist. **Week-over-week deltas:** current week mean minus previous week mean (weight always; BF only if both weeks have a mean BF). First week has **nil** deltas.  
**How:** `computeWeeklyLossRates`. Labels from **`MMM dd`** on week start.

**Example 1**  
- **Toy inputs:** Two consecutive weeks with mean weight **80** and **79** kg.  
- **Expected output:** Second point **`deltaWeightKg = −1.0`** (illustrative).

---

## 12. Pre-workout nutrition (scatter / chart)

**Definition**  
**What:** For each **workout** whose calendar day is in **`[dateStart, dateEnd]`** (start-of-day compared): consider **nutrition log entries** (`startDate`) with **`dateOnly`** in the same range. **Pre window:** **`[workout.startTime − 4 h, workout.startTime]`** (`preWorkoutWindowHours`). Sum **calories, protein, carbs, fat** over all entries in that window (multiple meals).  
**Minutes before workout:** Integer minutes from **last** pre meal’s `startDate` to **workout start** (floor division).  
**Timing quality:** **Good** if minutes ∈ **[60, 120]**; **ok** if **&lt; 60** (too close); **bad** if **&gt; 120** (too early).  
**How:** `computeWorkoutNutrition` + `classifyPreWorkoutTiming`.

**Example 1**  
- **Toy inputs:** Last meal **90 min** before lift.  
- **Expected output:** **good** timing.

---

## 13. Post-workout nutrition (scatter / chart)

**Definition**  
**What:** **Post window:** **`[workout.endTime, workout.endTime + 4 h]`**. Sum macros over entries in that window. **Minutes after:** from **workout end** to **first** post meal’s `startDate`. **Quadrant / quality:** **Good** if **≤ 120 min** and **protein ≥ 40 g** (`proteinPostWorkoutTargetG`); **bad** if **both** late (&gt; 120 min) **and** low protein; else **ok**.  
**How:** `classifyPostWorkoutQuadrant`.

**Example 1**  
- **Toy inputs:** First meal **90 min** after, **45 g** protein.  
- **Expected output:** **good**.

---

## 14. Pre-workout macro targets (card / legend)

**Definition**  
**What:** **Protein target (g)** = **`0.3 × avgWeightKg`**; **carbs target (g)** = **`0.5 × avgWeightKg`**, where **`avgWeightKg`** is the **simple mean of all non-nil scale weights ever loaded** (not range-limited).  
**How:** `computeAvgWeightKg` + `PreWorkoutTargets`. If no weights → **`nil`** targets.

**Example 1**  
- **Toy inputs:** Mean weight **80 kg**.  
- **Expected output:** **24 g** protein, **40 g** carbs targets.

---

## Reference constants (Nutrition)

| Item | Value | Role |
|------|--------|------|
| `minCaloriesForFiltering` | 500 | Drop low-days from macro pipeline |
| Protein / carbs / fat kcal/g | 4 / 4 / 9 | Macro % denominators |
| `rollingWindowDays` | 7 | Daily kcal rolling; calorie-balance 7d lines; weight/BF rolling |
| `empiricalRollingWindowDays` | 14 | Intake rolling avg & weight delta span for empirical TDEE |
| `kcalPerKgBodyWeight` | 7700 | Converts kg/day trend to kcal for empirical TDEE |
| `preWorkoutWindowHours` / `postWorkoutWindowHours` | 4 / 4 | Meal windows around training |
| `preWorkoutTimingGoodMin` / `Max` | 60 / 120 min | Pre timing **good** band |
| `postWorkoutTimingTargetMin` | 120 min | Post “in time” cutoff |
| `proteinPostWorkoutTargetG` | 40 | Post **good** protein threshold |
| `preWorkoutChartAxisMaxMinutes` | 200 | X-axis span for pre chart |
