import Charts
import FocusFlowCore
import SwiftUI

struct StatisticsView: View {
    @ObservedObject var app: AppModel
    @State private var period: StatisticsPeriod = .day
    @State private var tagID: UUID?
    @State private var showIncomplete = true
    @State private var showResetConfirmation = false

    // Cached derived data
    @State private var filteredRecords: [SessionRecord] = []
    @State private var groupedRecords: [(day: Date, records: [SessionRecord])] = []
    @State private var summary: StatisticsSummary = StatisticsSummary()

    private struct FilterParams: Equatable {
        let period: StatisticsPeriod
        let tagID: UUID?
        let showIncomplete: Bool
        let records: [SessionRecord]
    }

    private var filterParams: FilterParams {
        FilterParams(
            period: period,
            tagID: tagID,
            showIncomplete: showIncomplete,
            records: app.records
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            summaryStrip
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            // The chart plots one bar per day, so it's only meaningful across a
            // multi-day range. On the Day period a single day-unit bar stretches
            // across the whole plot as one giant block, so hide it there.
            if period != .day && !filteredRecords.isEmpty {
                chartSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(height: 180)

                Divider()
            }

            sessionList
        }
        .confirmationDialog("Reset all session data?", isPresented: $showResetConfirmation) {
            Button("Reset All Sessions", role: .destructive) {
                app.resetStatistics()
            }
        } message: {
            Text("This will permanently delete all recorded sessions. This action cannot be undone.")
        }
        .onChange(of: filterParams, initial: true) { _, params in
            let filtered = StatisticsCalculator.records(
                from: params.records,
                period: params.period,
                tagID: params.tagID,
                showIncomplete: params.showIncomplete
            )
            filteredRecords = filtered
            groupedRecords = StatisticsCalculator.grouped(records: filtered)
            summary = StatisticsCalculator.summary(for: filtered)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker(selection: $period) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Period")
            .frame(maxWidth: 300)

            Picker(selection: $tagID) {
                Text("All Tags").tag(UUID?.none)
                ForEach(app.tags) { tag in
                    Text(tag.title).tag(Optional(tag.id))
                }
            } label: {
                EmptyView()
            }
            .accessibilityLabel("Tag filter")
            .frame(width: 132)

            Toggle("Show skipped", isOn: $showIncomplete)
                .toggleStyle(.checkbox)
                .font(.subheadline)

            Spacer()

            Menu {
                Button {
                    app.exportCSV()
                } label: {
                    Label("Export CSV…", systemImage: "square.and.arrow.down")
                }

                Divider()

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset All Data…", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("More actions")
        }
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        HStack(spacing: 8) {
            SummaryTile(
                icon: "brain.head.profile",
                title: "Focus Sessions",
                value: "\(summary.completedFocusCount)",
                color: .accentColor
            )
            SummaryTile(
                icon: "clock",
                title: "Focus Time",
                value: DurationFormatter.compact(summary.totalFocusSeconds),
                color: .accentColor
            )
            SummaryTile(
                icon: "cup.and.saucer",
                title: "Breaks",
                value: "\(summary.completedBreakCount)",
                color: .green
            )
            SummaryTile(
                icon: "pause.circle",
                title: "Interruptions",
                value: "\(summary.interruptionCount)",
                color: .orange
            )
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        Chart {
            ForEach(groupedRecords, id: \.day) { group in
                let focusSeconds = group.records
                    .filter { $0.phase == .focus }
                    .reduce(0) { $0 + $1.actualSeconds }
                
                BarMark(
                    x: .value("Date", group.day, unit: .day),
                    y: .value("Focus Time (hours)", Double(focusSeconds) / 3600.0)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                if let val = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(val, specifier: "%.1f")h")
                    }
                }
            }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            if filteredRecords.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions", systemImage: "timer")
                } description: {
                    Text("Completed sessions will appear here.")
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ForEach(groupedRecords, id: \.day) { group in
                    Section(AppFormatters.dayHeader(for: group.day)) {
                        ForEach(group.records) { record in
                            SessionRow(record: record, tag: tag(for: record.tagID))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        app.deleteRecord(id: record.id)
                                    } label: {
                                        Label("Delete Session", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func tag(for id: UUID?) -> Tag? {
        guard let id else { return nil }
        return app.tags.first { $0.id == id }
    }
}

// MARK: - Summary Tile

private struct SummaryTile: View {
    var icon: String
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color.opacity(0.8))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    var record: SessionRecord
    var tag: Tag?

    var body: some View {
        HStack(spacing: 10) {
            // Phase icon
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(record.completed ? Color.phase(record.phase) : .secondary)
                .frame(width: 24)

            // Title & time
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.title.isEmpty ? record.phase.displayName : record.title)
                        .font(.body)
                        .lineLimit(1)

                    if !record.completed {
                        Text("Skipped")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Text("\(AppFormatters.time.string(from: record.startedAt)) · \(DurationFormatter.compact(record.actualSeconds))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Tag badge
            if let tag {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.tag(tag.colorName))
                        .frame(width: 7, height: 7)
                    Text(tag.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Phase label
            Text(record.phase.displayName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize()
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch record.phase {
        case .focus:
            "brain.head.profile"
        case .shortBreak, .longBreak:
            "cup.and.saucer"
        case .ready, .paused, .completed:
            "circle"
        }
    }
}
