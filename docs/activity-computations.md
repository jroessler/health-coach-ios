# Activity page

This document describes the **pure math** behind the Activity screen (`ActivityComputer`, `ActivityConstants`). Dates use the app’s ISO-8601 calendar with **Monday** as the first weekday where week bucketing applies.

---

## 1. Workout KPIs — Total Workouts

**Definition**  
**What:** The number of workouts stored in the app **without** applying the chart date filter (all parsed rows in the workouts table).  
**How:** Raw count from the database. If it is **0**, every workout KPI is zero and downstream workout math is skipped.

**Example 1**  

- **Toy inputs:** The database contains **12** workouts total (some inside the chart range, some outside).  
- **Expected output:** **Total workouts = 12.**

**Example 2**  

- **Toy inputs:** No workouts exist; `totalWorkoutCount = 0`.  
- **Expected output:** **Total workouts = 0**; all other workout KPI fields are **0** (including `priorDays` on that early-return path).

---

## 2. Workout KPIs — Workouts (Last Xd)

The card title shows **“Workouts (Last Xd)”** where **X** is `priorDays` from the computation below. The large number is the **recent** count; the subtitle compares it to the **prior** block (labeled “vs avg” in the UI).

### Period length

**Definition**  
**What:** The number of days **X** used for the “recent” and “prior” windows in this card (and in §4).  
**How:** `X = min(30, rangeDays)` where `rangeDays` is the inclusive length of the selected chart range in calendar days (`(dateEnd − dateStart).days + 1`).

**Example 1**  

- **Toy inputs:** Selected range = **14** calendar days (e.g. 1st–14th of a month).  
- **Expected output:** **X = 14** (UI: “Last 14d”).

**Example 2**  

- **Toy inputs:** Selected range = **90** calendar days.  
- **Expected output:** **X = 30** (capped; UI: “Last 30d”).

### Workout counts

**Definition**  
**What:**  

1. **Recent count:** Workouts whose `**startTime`** lies in **[dateEnd − (X−1) days, dateEnd]** (inclusive).
2. **Prior count:** Workouts whose `**startTime`** lies in **[dateStart − X days, dateStart]** (inclusive).
3. **Delta (subtitle):** `recent count − prior count`. The “avg” line compares to the **prior block’s count**, not an average per day.

**How:** Filter parsed workouts by `startTime`; count rows in each window.

**Example 1**  

- **Toy inputs:** **X = 7**. Recent window: **5** workouts. Prior window: **3** workouts.  
- **Expected output:** Main value **5**; delta **5 − 3 = +2** (e.g. “↑2.0 vs avg”).

**Example 2**  

- **Toy inputs:** **X = 30** and the selected range is longer than 30 days. Recent window = only the **last 30 days ending at `dateEnd`**; prior window = **30 days ending at `dateStart`** (they do not cover the whole range). Recent count **12**, prior count **15**.  
- **Expected output:** Main value **12**; delta **12 − 15 = −3** (e.g. “↓3.0 vs avg”).

---

## 3. Workout KPIs — Avg Duration Overall

**Definition**  
**What:** The average session length across **all** parsed workouts (lifetime), in minutes.  
**How:** Arithmetic mean of `durationMin` over every workout row (not filtered by the chart range).

**Example 1**  

- **Toy inputs:** Three workouts: **40**, **50**, **60** minutes.  
- **Expected output:** **50** min (shown as integer minutes in the UI).

**Example 2**  

- **Toy inputs:** One workout: **47.8** minutes; others average out so lifetime mean is **47.8**.  
- **Expected output:** Card shows **47** min (`Int(47.8)`).

---

## 4. Workout KPIs — Avg Duration (Last Xd)

The card title matches **X** from §2 (“Avg Duration (Last Xd)”). The main value is the **recent** window’s mean duration; the subtitle is the delta **vs prior** (not vs overall).

### Period alignment

**Definition**  
**What:** The same **X** and the same **recent** / **prior** time windows as §2 (Workout counts).  
**How:** No separate formula — reuse `priorDays` and the `lastStart` / `priorStart`–`priorEnd` bounds from `computeWorkoutKPIs`.

### Means and delta

**Definition**  
**What:**  

- **Main value:** Mean `durationMin` over workouts in the **recent** window (same filter as the Workouts card’s recent count). **0** if none.  
- **Prior mean (not shown as the headline):** Mean `durationMin` over the **prior** window; **0** if none.  
- **Delta (subtitle):** `mean(recent) − mean(prior)` — positive means longer sessions in the recent window.

**How:** Arithmetic mean per window; no weighting by volume.

**Example 1**  

- **Toy inputs:** Recent window: **2** workouts at **50** and **70** min → mean **60**. Prior window: **2** workouts at **45** min → mean **45**.  
- **Expected output:** Main value **60** min; delta **+15** min vs prior.

**Example 2**  

- **Toy inputs:** Recent window: **0** workouts → mean **0**. Prior window: **4** workouts averaging **48** min.  
- **Expected output:** Main value **0** min; delta **0 − 48 = −48** min vs prior.

---

## 5. Muscle Distribution (Chart)

Section title in the app: **“Muscle Distribution”** (`MuscleRadarChart`). The **polygon and legend** use `**currentRatios`** (capped at 150% on the axis) and **“Last daysUsed)d”**.

### Current window — set counts

**Definition**  
**What:** For each coarse muscle, how many **sets** fall in the **current** radar window.  
**How:**  

- Exclude `setType == "warmup"`. Map exercise → fine muscle (`templateMap`), then fine → coarse; drop unmapped/Other that has no coarse bucket.  
- `maxDays = min(rangeDays, 30)` with `rangeDays ≥ 1`.  
- **Current:** set `date` in **[max(dateStart, dateEnd − maxDays), dateEnd]** (with `currentStart = dateEnd − maxDays` in seconds).  
- Count **sets** per muscle; every radar muscle key exists (0 allowed).

**Example 1**  

- **Toy inputs:** `maxDays = 7`. Current window: **6** working sets on **Chest**.  
- **Expected output:** `currentCounts["Chest"] = 6` (other muscles 0 unless data exists).

**Example 2**  

- **Toy inputs:** Range **45** days → `maxDays = 30`. **Legs:** **10** sets in the current window.  
- **Expected output:** `currentCounts["Legs"] = 10`.

### Current window — adherence ratios (what the radar plots)

**Definition**  
**What:** Per muscle, **actual sets ÷ expected sets**, where **expected** = `weeklyTarget[muscle] × (periodDays / 7)` and `periodDays` is the inclusive calendar length from `**effectiveCurrentStart`** through `**dateEnd`**. Missing or zero weekly target → ratio **0**.  
**How:** Uses `currentCounts` and per-muscle weekly set targets from preferences. The chart maps `min(1.5, ratio) × 100` onto the 0–150% rings.

**Example 1**  

- **Toy inputs:** Chest target **7** sets/week. Current ratio window = **7** calendar days → expected `7 × (7/7) = 7` sets. Actual Chest sets = **7**.  
- **Expected output:** `currentRatios["Chest"] = 1.0` → polygon vertex at **100%** ring.

**Example 2**  

- **Toy inputs:** Legs target **14** sets/week. Current window **14** days → expected `14 × (14/7) = 28` sets; actual **21**.  
- **Expected output:** Current ratio **0.75** (vertex at **75** on the 0–150 scale before cap).

---

## 6. Volume Progression (Chart)

### Weekly volume (aggregation)

**Definition**  
**What:** For each **ISO week** (Monday start) and each coarse muscle, total **volume** = sum of **weightKg × reps** over non-warmup sets that map to that muscle. Only data from the last **7** weeks of span before `dateEnd` is considered (`volumeWeeks + 1` in code); the table keeps the **last 6** week columns that exist.  
**How:** Same warmup/template/coarse rules as the muscle chart; group by `monday(date)` and muscle, then sum.

**Example 1**  

- **Toy inputs:** One week, **Chest** only: **3** sets, each **100 kg × 8** reps.  
- **Expected output:** That week’s Chest volume = **3 × 800 = 2,400** kg·reps.

**Example 2**  

- **Toy inputs:** Two consecutive weeks; **Back** week 1: **1,000** kg·reps total; week 2: **1,500** kg·reps.  
- **Expected output:** Stored weekly totals **1000** and **1500** for those columns (used as inputs to % change).

### Week-over-week % change

**Definition**  
**What:** For each muscle and each **pair of consecutive weeks** in the selected week columns, percent change from the **earlier** week to the **later** week. Tooltips show current and prior week volume.  
**How:** If **curr = 0** → **0%**; else if **prev = 0** → **100%**; else `round((curr − prev) / prev × 100)` (no clamp to ±100).

**Example 1**  

- **Toy inputs:** **Chest:** week A **1,000**, week B **1,500** kg·reps.  
- **Expected output:** **50%** for the B-vs-A column; tooltip current **1500**, prior **1000**.

**Example 2**  

- **Toy inputs:** **Back:** prev **0**, curr **800** → **100%** rule. **Biceps:** prev **400**, curr **0** → **0%**. **Legs:** prev **200**, curr **500** → **150%**.  
- **Expected output:** **100**, **0**, and **150** in those cells respectively.

---

## 7. Activity KPIs — Steps / Day, Stand Min / Day, Walk Speed

The grid shows three rings; each uses the same **period** copy: **“Last Y Days”** where **Y = priorDays** (not necessarily equal to **X** in §2).

### Period label (`priorDays`)

**Definition**  
**What:** **Y = min(30, rangeDays)** with the same `rangeDays` as elsewhere — shown on all three rings.  
**How:** Independent of workout **X**; only depends on chart date range length.

**Example 1**  

- **Toy inputs:** Range **7** days.  
- **Expected output:** **Y = 7** (“Last 7 Days”).

**Example 2**  

- **Toy inputs:** Range **45** days.  
- **Expected output:** **Y = 30** (capped).

### Steps / Day

**Definition**  
**What:** Average daily **steps** over days in `[dateStart, dateEnd]` that have activity rows.  
**How:** `Int(mean(steps))` (truncates toward zero).

**Example 1**  

- **Toy inputs:** Three days: **9,000**, **9,000**, **12,000** steps.  
- **Expected output:** **10,000** steps.

**Example 2**  

- **Toy inputs:** Two days: **9,800** and **10,200** steps → mean **10,000**.  
- **Expected output:** **10,000** steps.

### Stand Min / Day

**Definition**  
**What:** Average **stand** minutes over filtered days.  
**How:** Mean of `standMin`, then round to **1** decimal.

**Example 1**  

- **Toy inputs:** Two days: **120.0** and **120.0** minutes.  
- **Expected output:** **120.0** min.

**Example 2**  

- **Toy inputs:** **100.25** and **100.35** → mean **100.3**.  
- **Expected output:** **100.3** min.

### Walk Speed

**Definition**  
**What:** Average **walking speed** (km/h) over days that have a non-`nil` speed; days with no speed are **skipped** in the mean.  
**How:** Mean of `walkingSpeedKmh` where present; round to **2** decimals; if **all** nil → **0**.

**Example 1**  

- **Toy inputs:** **3.5**, **3.5**, **4.0** km/h on three days.  
- **Expected output:** **3.67** km/h (rounded).

**Example 2**  

- **Toy inputs:** Five days of rows; speed only on two days: **3.333** and **3.337** km/h.  
- **Expected output:** **3.34** km/h (mean of two, then 2-decimal round).

---

## 8. Energy (TDEE) (Chart)

### Quality filter (which days are plotted)

**Definition**  
**What:** Only days in `[dateStart, dateEnd]` where **basal ≥ 1,000** kcal **and** **active ≥ 50** kcal.  
**How:** Rows that fail are dropped entirely (gap in the series).

**Example 1**  

- **Toy inputs:** Day A: basal **1,500**, active **400** → kept. Day B: basal **900**, active **400** → dropped.  
- **Expected output:** Chart has **one** point (A), not B.

**Example 2**  

- **Toy inputs:** Day C: basal **1,200**, active **40** → dropped (active too low).  
- **Expected output:** C does not appear.

### Y-day rolling active energy (Y ≤ 7) & TDEE line

**Definition**  
**What:** For each plotted day (sorted), `**activeKcal7d`** is a **centered rolling mean** of the **active** kcal series, using a **nominal window of 7** days — but the series only contains **days that pass the quality filter**, so you have **n** points (`n` = number of plotted days). At each index the mean uses **all available neighbors** within that 7-day window; at the **edges** of the series the window is **shorter** (same behaviour as “if you select fewer than 7 days, the rolling average is shorter”). The legend’s **“effective” length** is `**Y = min(n, 7)`** (`effectiveDays` in code) — i.e. **Y ≤ 7**, and **Y = n** when **n < 7**.  
Each value is rounded to **1** decimal. The TDEE line uses **rolling active + basal kcal** for that same day when both exist.

**How — math (centered window, `window = 7`)**  
Let the filtered, **date-sorted** active values be **a[0], …, a[n−1]**. For each index **i** (0-based):

- **halfBefore** = `(7 − 1) / 2` = **3**, **halfAfter** = `7 / 2` = **3** (integer division).
- **lo** = `max(0, i − 3)`, **hi** = `min(n − 1, i + 3)`.
- **Rolling active at i** = arithmetic mean of **a[lo] … a[hi]** = `(sum of a[j] for j = lo…hi) / (hi − lo + 1)`.

So with **n ≥ 7** and **i** in the middle, you use **7** terms; with **n < 7** or **i** near the ends, you use **fewer** terms (clamped window). Implementation: `NutritionKPIMath.centeredRollingMean(activeValues, window: 7)` — same rule as the Daily Calories rolling kcal line.

**Example 1**  

- **Toy inputs:** **7** consecutive plotted days, each active **500** kcal, basal **1,500** kcal.  
- **Expected output:** **Y = 7** in the legend; rolling active **500.0** each day; TDEE **2,000** kcal per day if summed.

**Example 2**  

- **Toy inputs:** **5** plotted days with active kcal **200, 400, 600, 800, 1000** (all pass filter).  
- **Expected output:** **Y = 5** in the legend (`min(5,7)`); centered means use at most **5** points (e.g. middle index uses mean of all five → **600** kcal); edge indices use shorter spans per the **lo**/**hi** rule above.

---

## Reference constants (Activity)


| Constant            | Typical value | Role                                                                           |
| ------------------- | ------------- | ------------------------------------------------------------------------------ |
| `maxRadarDays`      | 30            | Caps muscle distribution window                                                |
| `volumeWeeks`       | 6             | Weeks used in volume progression                                               |
| `minBasalKcal`      | 1,000         | Energy chart quality filter                                                    |
| `minActiveKcal`     | 50            | Energy chart quality filter                                                    |
| `rollingWindowDays` | 7             | Nominal centered window for active kcal; legend **Y** = `min(plotted days, 7)` |


