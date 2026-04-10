import SwiftUI

struct PersonalSettingsView: View {
    @Environment(UserProfileStore.self) private var store

    @State private var draft = UserSettings.defaults()
    @State private var saveError: String?
    @State private var showSavedBanner = false

    private let bgColor = Color(hex: 0x02161C)
    private let cardBg = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        List {
            Section {
                Stepper(value: $draft.age, in: 1...120, step: 1) {
                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(draft.age)")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Stepper(value: $draft.heightCm, in: 50...250, step: 0.5) {
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        Text(String(format: "%.1f", draft.heightCm))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(cardBg)

                Picker("Gender", selection: $draft.gender) {
                    ForEach(streamlitGenderOptions, id: \.self) { Text($0).tag($0) }
                }
                .listRowBackground(cardBg)

                LongOptionPickerRow(
                    title: "Training experience",
                    selection: $draft.trainingExperience,
                    options: streamlitTrainingExperienceOptions,
                    bgColor: bgColor,
                    cardBg: cardBg,
                    accentCyan: accentCyan
                )

                LongOptionPickerRow(
                    title: "Diet",
                    selection: $draft.dietPhase,
                    options: streamlitDietPhaseOptions,
                    bgColor: bgColor,
                    cardBg: cardBg,
                    accentCyan: accentCyan
                )
            } header: {
                Text("Personal Information")
            } footer: {
                Text("Your age, height, and profile labels are used for coaching and charts.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Personal")
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
            draft = store.settings
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
            try store.saveSettings(draft)
            draft = store.settings
            showSavedBanner = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { showSavedBanner = false }
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// Full-screen option list so long labels (e.g. diet) are readable; the summary row wraps on this screen.
private struct LongOptionPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let bgColor: Color
    let cardBg: Color
    let accentCyan: Color

    var body: some View {
        NavigationLink {
            List {
                ForEach(options, id: \.self) { opt in
                    Button {
                        selection = opt
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(opt)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if selection == opt {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(accentCyan)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(cardBg)
                }
            }
            .scrollContentBackground(.hidden)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                Text(selection)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 4)
            .frame(minHeight: 44)
        }
        .listRowBackground(cardBg)
    }
}
