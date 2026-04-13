# Heart & Recovery page

This document describes the **pure math** behind the Heart page (`HeartComputer`, `HeartConstants`, chart views). Rolling stats use **left-aligned** windows (`leftRollingMean` / `leftRollingStd`) unless noted

`periodLength` is `Calendar.dateComponents(.day, from: dateStart, to: dateEnd).day` (0 if unset). The UI caps labels with `min(7, periodLength)` or `min(14, periodLength)` where noted.

---

## HRV & RHR — Baseline and Standard Deviation

Recovery KPIs (§2–3) and the HRV/RHR trend charts (§7, §9) use the **same** baseline and standard deviation series produced by `HeartComputer` (`computeHRV` / `computeRHR`). **RHR** follows the **identical** pipeline as **HRV**; only the metric (bpm vs ms) and band layout differ.

### Step 1 — Daily values

For each **calendar day** (after normalizing to **start of day** in the app calendar), aggregate all samples:

- **HRV:** arithmetic **mean** of all HRV readings (ms) assigned to that day.  
- **RHR:** arithmetic **mean** of all resting heart rate readings (bpm) assigned to that day.

### Step 2 — Extended history window

Inputs:

- chart `dateStart` / `dateEnd` (start-of-day bounds)
- `minDate` = earliest HRV record in storage (used as a floor for both HRV and RHR when building baselines)
- `periodDays` = **day span** between `dateStart` and `dateEnd` — used only to choose a branch

**Branch A — `periodDays ≤ 30` (short chart):**

- `baselineStart = max(minDate, dateEnd − 30 days)` (each at start-of-day).  
- You include **up to 30 days** of calendar history **ending at `dateEnd`**, but never before the first stored sample.  
- `baselineDays` reported to the UI = number of days from `baselineStart` to `dateEnd` (the actual span used).

**Branch B — `periodDays > 30` (long chart):**

- `baselineStart = dateStart`.  
- `baselineDays` in the UI is fixed at **30** (labeling); the math still uses all extended days from `baselineStart` through `dateEnd`.

Collect **all raw** HRV/RHR samples whose day lies in `[baselineStart, dateEnd]` — this is the **extended** range used only for baseline math.

### Step 3 — Ordered daily series on the extended range

Within that extended range, group by calendar day and take the **daily mean** again (same rule as Step 1). Then sort those days **by calendar date, ascending** (earliest → latest, i.e. chronological order). That yields a sequence **v₀ … v_{N−1}** where **vᵢ** is the daily HRV/RHR mean on the **i-th** day in that sorted list (**one value per day that has data**; days with no samples are omitted).

### Step 4 — Rolling baseline mean and SD (left-aligned)

On **v**, for each index **i** (each day in the sorted extended series):

- **Baseline (mean):** **Left-aligned rolling mean** with **window = 30**, `min_periods = 7`: average of **v[max(0, i−29) … i]** inclusive, **only if** that slice has **≥ 7** points; otherwise **nil**. Matches pandas `rolling(30, min_periods=7).mean()`.
- **SD:** **Sample** standard deviation (**ddof = 1**) over the **same** 30-day left-aligned slice, with the same `min_periods` semantics; if the std is undefined, the implementation stores **0** for SD. Matches `rolling(30, min_periods=7).std()`.

So every extended day gets a **(baseline, sd)** pair keyed by **date** (or nil baseline when there are fewer than 7 days in the window).

**Toy examples** (illustrative; window still **30** in the app — we use smaller **v** only to show the logic by hand):

**Example 1 — Fewer than 7 days in the slice → no baseline yet**  

- **Toy inputs:** Extended series has only **6** daily values **v₀…v₅** (e.g. six consecutive days with data).  
- **At indices i = 0…5:** each slice **v[max(0, i−29)…i]** has at most **6** points **< 7** → **baseline = nil** for every day (KPI/chart cannot use a rolling baseline until the series is long enough).

**Example 2 — First index where the window has exactly 7 points**  

- **Toy inputs:** **v₀…v₆** each equal **50** (ms or bpm — same math).  
- **At i = 0…5:** slice length **< 7** → **baseline = nil**.  
- **At i = 6:** slice is **v₀…v₆** (7 points), all **50** → **baseline = 50**, **SD = 0** (no spread; sample variance is **0**).

**Example 3 — Seven distinct values (sample SD by hand)**  

- **Toy inputs:** **v₀…v₆ = 40, 42, 44, 46, 48, 50, 52** (7 days).  
- **At i = 6:** mean **μ = (40+…+52)/7 = 46**. Sample SD: **√(Σ(x−μ)² / 6)** ≈ **4.32** (implementation rounds only at display, not in the rolling helper).  
- **Expected output:** **baseline ≈ 46**, **SD ≈ 4.32** for that calendar day (mapped back by **date** in Step 5).

**Example 4 — Longer series (window up to 30 points)**  

- **Toy inputs:** Suppose **i = 29** and **v₀…v₂₉** are all available (30 points). The slice is the **full 30** values **v₀…v₂₉**.  
- **Baseline** = their arithmetic mean; **SD** = sample SD with **ddof = 1** over those **30** values (still requires **≥ 7** points and **≥ 2** for a non-degenerate variance path in code — with 30 distinct days, both hold).  
- **At i = 30:** slice is **v₁…v₃₀** (still up to **30** points): the window **slides** one day forward; baseline/SD update accordingly.

### Step 5 — Chart points and Recovery KPIs

- **Charts (selected range only):** For each displayed day in `[dateStart, dateEnd]`, look up that day’s **baseline and sd** from Step 4. Bands use those values (HRV: `baseline ± SD`, second lower band at `baseline − 2·SD`; RHR: upper stress bands at `baseline + SD` and `baseline + 2·SD`).
- **Recovery KPIs (§2–3):** “Latest” baseline and SD come from the **last row** of the **display-range** series (`points.last`). The headline **mean** is over the **last up to seven** `**.hrv` / `.rhr`** values among **those same display-range points only** (never days outside `[dateStart, dateEnd]`). Z-scores and % compare that mean to **that last row’s** baseline and SD.

---

## 1. Recovery KPIs — Recovery Score

**Definition**  
**What:** A single **0–100** score from the **HRV z-score** and **RHR z-score** computed in §2–3. Each z-score compares a **mean of daily HRV or daily RHR** (over the **last up to seven chart rows in the selected range**) to **baseline and SD on the last chart row** — see the **Recovery KPI note** under the title above.  
**How:**  

- `hrvZ = (mean(last up to 7 daily HRV values in range) − latestBaselineHRV) / latestSD` (0 if SD = 0).  
- `rhrZ = (latestBaselineRHR − mean(last up to 7 daily RHR values in range)) / latestSD` — **lower RHR is better**, so the formula rewards RHR below baseline.  
- `recoveryRaw = (hrvZ + rhrZ) / 2`  
- `recoveryScore = clamp(0…100, round(50 + recoveryRaw × 25))`.

**Example 1**  

- **Toy inputs:** `hrvZ = 0`, `rhrZ = 0` (both at baseline).  
- **Expected output:** `recoveryRaw = 0` → **50** points.

**Example 2**  

- **Toy inputs:** `hrvZ = 0.8`, `rhrZ = 0.8`.  
- **Expected output:** `recoveryRaw = 0.8` → `50 + 20 = 70` → **70** (after rounding/clamp).

---

## 2. Recovery KPIs — HRV (Last 7d) vs Baseline

**Card title:** **“HRV (**`min(7, periodLength)`**d) vs Baseline (**`baselineDaysHRV`**d)”** 

**Scope (important):** `hrv.points` contains **only** HRV for the **selected chart range** (each point is one day’s **daily mean** HRV). The KPI mean is `**mean` of `suffix(7)`** on that array: **at most seven** values, taken from the **end** of the range. If the range has **3** days with points, the mean uses **3** values. **No** data are read from **before `dateStart`** or **after `dateEnd`**.

**Baseline & SD:** From **“HRV & RHR — baseline and standard deviation”** (30‑day rolling mean & SD on daily HRV, `min_periods = 7`).

### Fields (`RecoveryKPIs` / `computeRecoveryKPIs`)


| Field           | Definition                                                                                                                                                    |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hrvToday`      | Mean of `**.hrv`** on the **last up to 7** entries of `hrv.points` (same as `tail(7)` then mean). Each `**.hrv`** is that day’s **daily** HRV (ms).           |
| `hrvBaseline`   | `**baseline`** on `**hrv.points.last`**, or **0** if nil.                                                                                                     |
| SD (for `hrvZ`) | `**sd`** on that same last row.                                                                                                                               |
| `hrvPct`        | `((hrvToday − hrvBaseline) / hrvBaseline × 100)` rounded to **1** decimal; **0** if baseline ≤ **0**. Higher HRV than baseline ⇒ **positive** % (favourable). |
| `hrvZ`          | `(hrvToday − hrvBaseline) / SD` if SD > **0**, else **0**. Drives card **colour** in the view.                                                                |


**Example 1**  

- **Toy inputs:** Mean over last **up to 7** daily values = **50 ms**; last row baseline **50 ms**, SD **10**.  
- **Expected output:** `hrvPct = 0%`, `hrvZ = 0`.

**Example 2**  

- **Toy inputs:** That mean = **60 ms**; baseline **50 ms**, SD **5**.  
- **Expected output:** `hrvPct = +20.0%`, `hrvZ = 2.0`.

**Example 3 — short range**  

- **Toy inputs:** Selected range has **3** chart days with HRV **48, 50, 52 ms** (only three `hrv.points`).  
- **Expected output:** `hrvToday = mean(48, 50, 52) = 50` ms — **not** an average over seven **calendar** days outside the range.

---

## 3. Recovery KPIs — RHR (Last 7d) vs Baseline

**Card title:** **“RHR (`min(7, periodLength)`d) vs Baseline (`baselineDaysRHR`d)”** — same labelling pattern as §2.

**Scope:** Identical to §2: `**rhr.points`** is **only** inside the selected chart range; the mean uses `**suffix(7)`** → **at most seven** daily RHR values, or **fewer** if the range is shorter.

**Baseline & SD:** Same pipeline as §2 — see **“HRV & RHR — baseline and standard deviation”**.

### Fields


| Field         | Definition                                                                                                                                                              |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rhrToday`    | Mean of `**.rhr`** on the **last up to 7** points of `rhr.points` — **daily RHR (bpm)**.                                                                                |
| `rhrBaseline` | `**baseline`** on `**rhr.points.last`**, or **0** if nil.                                                                                                               |
| SD            | `**sd`** on that last row.                                                                                                                                              |
| `rhrPct`      | `((rhrToday − rhrBaseline) / rhrBaseline × 100)` rounded to **1** decimal; **0** if baseline ≤ **0**. **Higher** RHR than baseline ⇒ **positive** % (**unfavourable**). |
| `rhrZ`        | `(rhrBaseline − rhrToday) / SD` if SD > **0**, else **0** — **lower** RHR than baseline ⇒ **positive** z (favourable). Drives card **colour**.                          |


**Example 1**  

- **Toy inputs:** Mean of last up to 7 daily values = **55 bpm**; baseline **55 bpm**, SD **5**.  
- **Expected output:** `rhrPct = 0%`, `rhrZ = 0`.

**Example 2**  

- **Toy inputs:** That mean = **65 bpm**; baseline **55 bpm**, SD **5**.  
- **Expected output:** `rhrPct ≈ +18.2%`, `rhrZ = −2.0`.

---

## 4. Recovery KPIs — HRV / RHR Signal

**Definition**  
**What:** One **divergence** value: `hrvZ − rhrZRaw`.

- `**rhrZRaw = (rhrToday −** latestBaselineRHR**) /** latestSD` — same algebraic shape as `**hrvZ = (hrvToday − baselineHRV) / SD`**: positive when the **recent mean is above** your baseline. For RHR, that is **unfavourable** (matches **%**: high RHR ⇒ positive).  
- **Recall:** 
  - `hrvZ = (mean(last up to 7 daily HRV values in range) − latestBaselineHRV) / latestSD`
  - `rhrZ = (latestBaselineRHR − mean(last up to 7 daily RHR values in range)) / latestSD`

**Why `hrvZ − rhrZRaw` and not `hrvZ − rhrZ`?**  
If you used `hrvZ − rhrZ`**, both terms would be positive when recovery looks good (high HRV vs baseline and low RHR vs baseline). Those two “good” z-scores would often be similar in magnitude, so their difference would sit near zero even when both metrics agree you are in a good state — the Signal would read “Neutral” by mistake. Using** `rhrZRaw` keeps the second term in the **stress-aligned** direction (high recent RHR ⇒ positive). Then **favourable** HRV (**positive `hrvZ`**) and **favourable** RHR (**negative `rhrZRaw`**) **add** in `hrvZ − rhrZRaw`, and **conflict** (e.g. HRV up, RHR up) shows up as a smaller or negative divergence.

**How:** Map divergence to a **label** + short **detail** string (`Optimal` / `Aligned` / `Neutral` / `Diverging` / `Stressed`).

**Example 1**  

- **Toy inputs:** `hrvZ = 0`, `rhrZRaw = 0`.  
- **Expected output:** **Divergence = 0** → **“Neutral”** / “No clear signal”.

**Example 2**  

- **Toy inputs:** `hrvZ = 1.0`, `rhrZRaw = −0.5` (HRV above baseline, RHR below baseline — both “good” directions in raw space).  
- **Expected output:** `divergence = 1.5` → **“Optimal”** / “HRV↑ · RHR↓”.

---

## 5. Fitness KPIs — VO₂ Max (Last)

**Definition**  
**What:** 

- The **latest** daily VO₂ max in the chart series (`vo2Max` on the **last** `VO2DayPoint`).

**Example 1**  

- **Toy inputs:** Last day VO₂ = **48.5** ml/kg/min.  
- **Expected output:** Card shows **48.5 ml/kg/min**.

**Example 2**  

- **Toy inputs:** No VO₂ rows in range.  
- **Expected output:** **N/A**.

---

## 6. Fitness KPIs — VO₂ Max (14D Avg) vs Baseline (30D)

**Definition**  
**What:** 

- **Delta = last day’s 30d rolling baseline − last day’s 14d rolling mean** (`vo2_baseline.last − vo214d.last`). Positive ⇒ short-term average below long-term baseline. 
- VO₂ baseline uses the same extended-window rule as Step 2 in HRV and RHR baseline, but its 30-day baseline is a rolling mean with min_periods = 1, so a baseline can appear with less than 7 days of history.
**How:** Both series come from `computeVO2`; if either is missing on the last point, delta is **N/A**.

**Example 1**  

- **Toy inputs:** Last **baseline** = **46**, last **14d mean** = **45**.  
- **Expected output:** **+1.0**.

**Example 2**  

- **Toy inputs:** Baseline **44**, 14d mean **46**.  
- **Expected output:** **−2.0**.

---

## 7. HRV Trend + Personal Baseline (Chart)

### Daily HRV and 7d line

**Definition**  
**What:** For each day in the selected range: **daily HRV** = mean of all HRV readings that day. **hrv7d** = **left-aligned 7-day rolling mean** of those daily values (`min_periods = 1`).  
**How:** Multiple readings per day are averaged first; then rolling on the daily series.

**Example 1**  

- **Toy inputs:** Seven days all **50 ms** daily.  
- **Expected output:** **hrv7d = 50** on every day once the window is full; first days use fewer points.

**Example 2**  

- **Toy inputs:** Daily values strictly increasing **40…46** over 7 days.  
- **Expected output:** **hrv7d** rises toward the **mean of the last up-to-7** slice (exact numbers follow `leftRollingMean`).

### Baseline and SD bands

**Definition (summary):** On an **extended** date range, build a **daily** mean series, then apply a **30-day left-aligned rolling mean** and **30-day sample SD** (`min_periods = 7`, `ddof = 1`, SD **0** when undefined). **Full step-by-step** (extended-window rules, lookup by date, KPI vs chart usage): **“HRV & RHR — baseline and standard deviation”** at the top of this doc.

**What (per chart day):**  

- **Baseline** = rolling mean as above.  
- **SD** = rolling sample SD as above.  
**Bands:** `upper = baseline + SD`, `lower = baseline − SD`, `lower2 = baseline − 2×SD`; **% deviation** on the point = `((daily − baseline) / baseline × 100)` rounded to **1** dp if baseline > 0.

**Example 1**  

- **Toy inputs:** Daily HRV flat **50** for 30+ days; SD stable **5**.  
- **Expected output:** Baseline **50**, lower band **45**, lower2 **40**.

**Example 2**  

- **Toy inputs:** Fewer than **7** days in the rolling window → baseline/SD may be **nil** on early days (`min_periods` not met).

---

## 8. HRV Distribution (Chart)

**Definition**  
**What:** A **30-bin** histogram of **daily HRV values** in the chart (`data.points.map(\.hrv)`). Bin width = `(max − min) / 30`.  
**How:** Computed in the view; zone shading uses the **last** point’s baseline and SD from the same `HRVChartData` (same bands as the trend chart).

---

## 9. RHR Trend + Personal Baseline (Chart)

**Definition**  
**What:** Same structure as HRV: **daily RHR** (mean per day), **rhr7d** = 7-day left rolling mean, **baseline** = 30-day rolling mean on the extended series, **SD** = 30-day rolling SD — see **“HRV & RHR — baseline and standard deviation”** for the exact algorithm. **RHR bands** use `**upper` / `upper2`** above baseline (stress when **high**).  
**How:** `computeRHR` mirrors `computeHRV` with RHR-specific band fields.

**Example 1**  

- **Toy inputs:** Daily RHR **55** bpm every day for 30+ days; SD **3**.  
- **Expected output:** Baseline **55**, upper **58**, upper2 **61**.

**Example 2**  

- **Toy inputs:** Same as §7 Example 2 — early days can lack baseline/SD until enough history exists.

---

## 10. HRV vs RHR (Chart)

**Definition**  
**What:** **Presentation only:** overlays **HRV** and **RHR** time series (daily + 7d lines) on a shared date axis with separate **y**-scales.  
**How:** No extra computation beyond the two `HRVChartData` / `RHRChartData` inputs.

---

## 11. VO₂ Max Trend (Chart)

**Definition**  
**What:** **Daily VO₂** = mean of samples that day; **vo214d** = **14-day** left rolling mean (`min_periods = 1`); **baseline** = **30-day** left rolling mean on the **extended** VO₂ daily series (`min_periods = 1` for baseline in code).  
**How:** Extended-range rule matches HRV/RHR (≤30-day vs >30-day selection).

---

## 12. VO₂ Max vs Body Weight (Chart)

**Definition**  
**What:** Aligns **dates** that have VO₂ and/or weight; **weight 7d** = left rolling mean of daily weight (`min_periods = 1`); **forward-fills** weight-7d and VO₂ **baseline** across the merged timeline; **VO₂ absolute** = `VO₂max × forward-filled weight (7d)`; **VO₂ absolute 14d** = 14-day rolling mean of that absolute series (optional values).  
**How:** If there is **no** VO₂ in the selected range, the chart is **hidden** (`nil`).

**Example 1**  

- **Toy inputs:** VO₂ **50**, filled weight **80 kg** → absolute **4000** (units: ml/kg/min × kg).  
- **Expected output:** Point lies on the scatter/trend at **4000** for that day’s absolute value.

**Example 2**  

- **Toy inputs:** Weight missing several days; **ffill** carries last known **7d** weight forward before multiplying.  
- **Expected output:** Absolute series has no gaps where ffill + VO₂ exist; **14d** smooths the absolute series.

---

## 13. HRV vs Training Volume (1–2 Day Lag) (Chart)

**Definition**  
**What:** For each day in the HRV-filled range: **lagged volume** = `**max(volume on day−1, volume on day−2)`** (training volume from lifting: **Σ weight × reps** per calendar day). **HRV 7d** = optional rolling mean of daily HRV on that timeline.  
**How:** Requires non-empty HRV map; **averagePeriod** = `min(7, periodLength)`.

**Example 1**  

- **Toy inputs:** Volume **1000** on Monday, **0** on Tuesday; viewing Wednesday.  
- **Expected output:** `laggedVolume = max(Tue, Mon) = 1000`.

**Example 2**  

- **Toy inputs:** Volume only on **day 0**; on **day 1**, `lag1` has volume, `lag2` does not → lagged uses **day 0** volume.  
- **Expected output:** Lagged value equals **max** of the two lookbacks.

---

## 14. HRV vs Session Performance (Chart)

**Definition**  
**What:** **Morning HRV** = first reading each day (earliest `startDate`); only days with **volume > 0** are kept; need **≥ 5** such days **globally** to build percentiles, and **≥ 5** days **inside the selected range** to show the chart. **Zones:** Low / Moderate / High by **HRV** vs **p33** and **p66** of all joined HRV values. **Zone averages** = mean **volume** per zone (range points only). **Regression** = OLS of **volume ~ HRV** on range points.  
**How:** Percentiles use **linear interpolation** between sorted values.

**Example 1**  

- **Toy inputs:** Five days, HRV **30, 40, 50, 60, 70**, volumes **1000** each; range includes all five.  
- **Expected output:** `p33` / `p66` split HRV into thirds; zone averages all **1000**; slope ≈ **0** if volume flat.

**Example 2**  

- **Toy inputs:** Only **4** qualifying days.  
- **Expected output:** Chart **not shown** (`nil`).

---

## Reference constants (Heart)


| Item                  | Value                    | Role                                                                                  |
| --------------------- | ------------------------ | ------------------------------------------------------------------------------------- |
| Baseline window       | 30 days                  | Left-aligned rolling on **daily** series; **min_periods = 7** for mean & SD (HRV/RHR) |
| Baseline SD (HRV/RHR) | 30-day sample SD         | `ddof = 1`; 0 when undefined (filled)                                                 |
| HRV/RHR 7d rolling    | 7 days                   | Trend lines (`min_periods = 1`)                                                       |
| VO₂ 14d rolling       | 14 days                  | Short-term VO₂                                                                        |
| VO₂ baseline rolling  | 30 days                  | Long-term VO₂                                                                         |
| Age-based VO₂ refs    | `HeartConstants.vo2Refs` | Fitness KPI coloring                                                                  |
| Longevity goal VO₂    | 52 ml/kg/min             | Goal line on fitness card                                                             |


