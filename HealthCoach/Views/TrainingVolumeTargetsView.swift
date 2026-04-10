import SwiftUI

struct TrainingVolumeTargetsView: View {
    @Environment(UserProfileStore.self) private var store

    @State private var draft = UserPreferences.defaults()
    @State private var saveError: String?
    @State private var showSavedBanner = false

    private let bgColor = Color(hex: 0x02161C)
    private let cardBg = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        List {
            Section {
                setStepper(title: "Legs (sets / week)", value: $draft.targetSetsLegs)
                setStepper(title: "Back (sets / week)", value: $draft.targetSetsBack)
                setStepper(title: "Chest (sets / week)", value: $draft.targetSetsChest)
            } header: {
                Text("Volume")
            }

            Section {
                setStepper(title: "Shoulders (sets / week)", value: $draft.targetSetsShoulders)
                setStepper(title: "Triceps (sets / week)", value: $draft.targetSetsTriceps)
            } header: {
                Text("Arms & shoulders")
            }

            Section {
                setStepper(title: "Biceps (sets / week)", value: $draft.targetSetsBiceps)
                setStepper(title: "Abs (sets / week)", value: $draft.targetSetsAbs)
            } header: {
                Text("Other")
            } footer: {
                Text("These weekly set targets are used to evaluate balance across muscle groups. Saving applies the same checks as on the Nutrition screen.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Training volume")
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

    private func setStepper(title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...40, step: 1) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(cardBg)
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
