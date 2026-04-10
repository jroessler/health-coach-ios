import SwiftUI

struct NutritionPreferencesView: View {
    @Environment(UserProfileStore.self) private var store

    @State private var draft = UserPreferences.defaults()
    @State private var saveError: String?
    @State private var showSavedBanner = false

    private let bgColor = Color(hex: 0x02161C)
    private let cardBg = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    private var macroSum: Int {
        draft.targetProteinPct + draft.targetCarbsPct + draft.targetFatPct
    }

    private var macroSumValid: Bool {
        macroSum == 100
    }

    var body: some View {
        List {
            Section {
                Stepper(value: $draft.targetProteinPct, in: 10...60, step: 1) {
                    HStack {
                        Text("Target protein (%)")
                        Spacer()
                        Text("\(draft.targetProteinPct)")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Stepper(value: $draft.targetCarbsPct, in: 10...70, step: 1) {
                    HStack {
                        Text("Target carbs (%)")
                        Spacer()
                        Text("\(draft.targetCarbsPct)")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Stepper(value: $draft.targetFatPct, in: 10...60, step: 1) {
                    HStack {
                        Text("Target fat (%)")
                        Spacer()
                        Text("\(draft.targetFatPct)")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                HStack {
                    Text("Macro total")
                    Spacer()
                    Text("\(macroSum)%")
                        .foregroundStyle(macroSumValid ? Color.secondary : Color.red)
                        .fontWeight(.semibold)
                }
                .listRowBackground(cardBg)
            } header: {
                Text("Macro targets")
            } footer: {
                if !macroSumValid {
                    Text("Macro targets must sum to 100%. Currently: Protein \(draft.targetProteinPct)% + Carbs \(draft.targetCarbsPct)% + Fat \(draft.targetFatPct)% = \(macroSum)%.")
                        .foregroundStyle(.red.opacity(0.9))
                } else {
                    Text("Target percentage of calories from each macro.")
                }
            }

            Section {
                Stepper(value: $draft.fiberTargetG, in: 10...80, step: 1) {
                    HStack {
                        Text("Fiber target (g/day)")
                        Spacer()
                        Text("\(draft.fiberTargetG)")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Stepper(value: $draft.sugarLimitG, in: 20...150, step: 1) {
                    HStack {
                        Text("Sugar limit (g/day)")
                        Spacer()
                        Text("\(draft.sugarLimitG)")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Stepper(value: $draft.weeklyWeightLossTargetKg, in: -2.0...0.0, step: 0.1) {
                    HStack {
                        Text("Weekly weight loss (kg/wk)")
                        Spacer()
                        Text(String(format: "%.1f", draft.weeklyWeightLossTargetKg))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Stepper(value: $draft.weeklyBodyfatLossTargetPct, in: -1.0...0.0, step: 0.1) {
                    HStack {
                        Text("Weekly body fat loss (%/wk)")
                        Spacer()
                        Text(String(format: "%.1f", draft.weeklyBodyfatLossTargetPct))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)
            } header: {
                Text("Other nutrition targets")
            } footer: {
                Text("Weekly targets are negative during a cut (loss).")
            }
        }
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .tint(accentCyan)
            }
        }
        .onAppear {
            draft = store.preferences
        }
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            if let saveError { Text(saveError) }
        }
        .safeAreaInset(edge: .bottom) {
            if showSavedBanner {
                Text("Settings saved. Changes will apply across the app.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(cardBg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedBanner)
    }

    private func save() {
        do {
            try store.savePreferences(draft)
            draft = store.preferences
            showSavedBanner = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { showSavedBanner = false }
            }
        } catch {
            if let e = error as? UserProfileSaveError, case .validation(let msg) = e {
                saveError = msg
            } else {
                saveError = error.localizedDescription
            }
        }
    }
}
