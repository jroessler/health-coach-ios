# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HealthCoach is an iOS app (Swift, SwiftUI) that integrates health data from Apple Health, Hevy (strength training), and manual nutrition entries. It computes KPIs across three domains (heart, activity, nutrition) and uses the Anthropic Claude API to generate personalized health coaching summaries and interactive coaching conversations.

**Key Stack:**
- Language: Swift 5.9, iOS 17.0+
- UI: SwiftUI
- Local Data: SwiftData (app models); GRDB for high-volume health records
- External APIs: Apple HealthKit, Hevy API, Anthropic Messages API
- Key Dependencies: GRDB.swift (7.0.0+), MarkdownUI (2.4.1+)

## Commands

### Build

```bash
xcodebuild -scheme HealthCoach -configuration Debug build
open HealthCoach.xcodeproj
```

### Test

```bash
# Full test suite
xcodebuild -scheme HealthCoach test

# Specific test class
xcodebuild -scheme HealthCoach -only-testing HealthCoachTests/ActivityKPIMathTests test

# Specific test method
xcodebuild -scheme HealthCoach -only-testing "HealthCoachTests/ActivityKPIMathTests/testTotalWorkouts_reflectsRawCount_notFilteredByRange" test
```

## Architecture

### Data Flow

The app is layered:

1. **Sync Layer** (`SyncService`) — Orchestrates fetching from HealthKit, Hevy API, and manual entries. Fetches monthly chunks. Updates SwiftData and GRDB. Published as `@Observable`.

2. **Computation Layer** (`ActivityComputer`, `HeartComputer`, `NutritionComputer`) — `@ModelActor` classes that run off-main-thread. Return immutable `Sendable` snapshot structs. All math delegated to corresponding `*KPIMath.swift` static functions.

3. **AI Coach Layer** (`CoachSnapshotBuilder`, `AnthropicService`) — `CoachSnapshotBuilder` converts snapshots into a token-efficient `CoachPayload` (only KPI scalars, no raw arrays). `AnthropicService` calls the Anthropic Messages REST API directly via `URLSession` (no SDK). Conversation history persisted in SwiftData.

4. **Persistence Layer**
   - **SwiftData:** `NutritionEntry`, `Workout`, `WorkoutSet`, `ExerciseTemplate`, `CoachSummary`, `ChatConversation`, `ChatMessage`
   - **GRDB:** `HealthRecordStore` singleton for Apple Health records (append-heavy workload)
   - **Keychain:** `KeychainService` for Anthropic API key
   - **UserDefaults:** Preferences, last sync times, reminder settings

### View Structure

Four-tab navigation (`ContentView`):

1. **Nutrition** → `NutritionView`
2. **Heart** → `HeartView`
3. **Activity** → `ActivityView`
4. **Coach** → `CoachTabView` (AI summaries + chat)

Modal: `DashboardView` (stats + sync controls), `SettingsView` (API key, reminders, personal settings)

### KPI Snapshots

Each domain has an immutable snapshot struct returned by its computer:
- `ActivitySnapshot` → workout KPIs, muscle radar data, volume progression, energy/TDEE
- `HeartSnapshot` → HRV/RHR baselines, recovery score, VO2, z-scores, performance zones
- `NutritionSnapshot` → daily macro summaries, calorie balance, weekly weight/body fat loss rates

All formulas are documented in `docs/activity-computations.md`, `docs/heart-computations.md`, and `docs/nutrition-computations.md` with toy input/output examples.

### Testing Pattern

- Descriptive names: `testXxx_expectedBehavior_whenYyyCondition`
- Toy inputs with known outputs derived from `docs/` formula specs
- Tests in `HealthCoachTests/` cover all `*KPIMath.swift` functions

## Key Conventions

**Concurrency:** `@ModelActor` for SwiftData off-main-thread; `Sendable` structs for cross-actor data; `@MainActor` for UI updates in `SyncService`.

**Dates:** HealthKit uses UTC; display uses local calendar. `ActivityKPIMath.activityCalendar` is the source of truth for week bucketing (Monday start). ISO-8601 `"yyyy-MM-dd"` strings in GRDB and computations.

**No third-party API SDKs:** `AnthropicService` and `HevyAPIService` use `URLSession` directly for fine-grained control.

**API Key:** Stored exclusively in Keychain via `KeychainService`. Set by the user in `SettingsView`.

**Adding a new KPI:** Update the `*Computer`, snapshot struct, `*KPIMath`, tests, `docs/`, `CoachSnapshotBuilder` (if surfacing to AI), and the relevant view — in that order.
