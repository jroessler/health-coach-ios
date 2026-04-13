import SwiftUI
import SwiftData

struct SummaryHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \CoachSummary.generatedAt, order: .reverse)
    private var summaries: [CoachSummary]

    private let bgColor    = Color(hex: 0x02161C)
    private let cardBg     = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    emptyState
                } else {
                    summaryList
                }
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Summary History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(accentCyan)
                }
            }
        }
    }

    // MARK: - List

    private var summaryList: some View {
        List {
            ForEach(summaries) { summary in
                NavigationLink {
                    SummaryDetailView(summary: summary)
                } label: {
                    summaryRow(summary)
                }
                .listRowBackground(cardBg)
            }
            .onDelete(perform: deleteSummaries)
        }
        .scrollContentBackground(.hidden)
    }

    private func summaryRow(_ summary: CoachSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.generatedAt, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                Label("\(summary.shortTermDays)d short", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(summary.longTermDays)d long", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 44))
                .foregroundStyle(accentCyan.opacity(0.4))
            Text("No summaries yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Generated summaries will appear here so you can review past insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete

    private func deleteSummaries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(summaries[index])
        }
    }
}

// MARK: - Detail view

struct SummaryDetailView: View {
    let summary: CoachSummary

    private let bgColor    = Color(hex: 0x02161C)
    private let cardBg     = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                metaHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.1))

                CoachMarkdownView(markdown: summary.markdownContent)
                    .padding(16)
            }
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(summary.generatedAt.formatted(.dateTime.month(.abbreviated).day().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: summary.markdownContent) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(accentCyan)
                }
            }
        }
    }

    private var metaHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.generatedAt, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(summary.generatedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                windowBadge(label: "S", days: summary.shortTermDays)
                windowBadge(label: "L", days: summary.longTermDays)
            }
        }
    }

    private func windowBadge(label: String, days: Int) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accentCyan)
            Text("\(days)d")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accentCyan.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
