import Charts
import FocusFlowCore
import SwiftUI

enum StatisticsTab {
    case overview, sessions
}

struct StatisticsView: View {
    @ObservedObject var app: AppModel

    @State private var selectedTab: StatisticsTab = .overview
    @State private var period: StatisticsPeriod = .day
    @State private var tagID: UUID?
    @State private var showIncomplete = true
    @State private var showResetConfirmation = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Caches
    @State private var overviewStreak: Int = 0
    @State private var overviewGoalProgress: Double = 0
    @State private var overviewGoalSeconds: Int = 0
    @State private var overviewFocusSeconds: Int = 0
    @State private var overviewHeatmap: [[Int]] = []

    @State private var overviewBestHours: [Int] = []
    @State private var overviewPerTag: [TagFocusBucket] = []

    private var filteredRecords: [SessionRecord] {
        StatisticsCalculator.records(
            from: app.records,
            period: period,
            tagID: tagID,
            showIncomplete: showIncomplete
        )
    }

    private var summary: StatisticsSummary {
        StatisticsCalculator.summary(for: filteredRecords)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            if selectedTab == .overview {
                overviewContent
            } else {
                sessionsContent
            }
        }
        .onAppear { refreshOverviewData() }
        .onChange(of: app.records) { refreshOverviewData() }
        .onChange(of: app.preferences.dailyGoalMinutes) { refreshOverviewData() }
        .onChange(of: period) { refreshOverviewData() }
        .onChange(of: tagID) { refreshOverviewData() }
        .onChange(of: showIncomplete) { refreshOverviewData() }
        .confirmationDialog("Reset all session data?", isPresented: $showResetConfirmation) {
            Button("Reset All Sessions", role: .destructive) {
                app.resetStatistics()
            }
        } message: {
            Text("This will permanently delete all recorded sessions. This action cannot be undone.")
        }
        .animation(reduceMotion ? nil : .default, value: selectedTab)
    }

    private func refreshOverviewData() {
        let allRecords = app.records
        let dailyGoal = app.preferences.dailyGoalMinutes

        overviewStreak = ProgressCalculator.currentStreak(records: allRecords, goalMinutes: dailyGoal, asOf: Date())
        overviewGoalProgress = ProgressCalculator.goalProgress(records: allRecords, goalMinutes: dailyGoal, on: Date())

        let totals = ProgressCalculator.dailyFocusTotals(records: allRecords)
        overviewFocusSeconds = totals[Calendar.current.startOfDay(for: Date())] ?? 0
        overviewGoalSeconds = dailyGoal * 60

        overviewHeatmap = ProgressCalculator.heatmapCells(records: allRecords, weeks: 12, endingOn: Date())

        let filtered = filteredRecords
        overviewBestHours = ProgressCalculator.bestHours(records: filtered)
        overviewPerTag = ProgressCalculator.tagFocusBuckets(records: filtered)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker(selection: $selectedTab) {
                Text("Overview").tag(StatisticsTab.overview)
                Text("Sessions").tag(StatisticsTab.sessions)
            } label: { EmptyView() }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Divider().frame(height: 16)

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

    // MARK: - Overview Content

    private var overviewContent: some View {
        ScrollView {
            if app.records.isEmpty {
                ContentUnavailableView {
                    Label("No focus history yet", systemImage: "chart.bar")
                } description: {
                    Text("Complete a focus session to see trends.")
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    summaryStrip
                    Divider()
                    heatmapSection
                    Divider()
                    chartsSection
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Sessions Content

    private var sessionsContent: some View {
        VStack(spacing: 0) {
            summaryStrip
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            if period != .day && !filteredRecords.isEmpty {
                chartSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(height: 180)

                Divider()
            }

            sessionList
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

            if selectedTab == .overview {
                SummaryTile(
                    icon: "flame.fill",
                    title: "Streak",
                    value: "\(overviewStreak) days",
                    color: .orange
                )
                if app.preferences.dailyGoalMinutes > 0 {
                    GoalTile(
                        title: "Daily Goal",
                        focusSeconds: overviewFocusSeconds,
                        goalSeconds: overviewGoalSeconds,
                        progress: overviewGoalProgress
                    )
                }
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Focus activity, last 12 weeks")
                .font(Theme.Typography.sectionHeader)

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<7, id: \.self) { row in
                    GridRow {
                        ForEach(0..<12, id: \.self) { col in
                            let seconds = overviewHeatmap.indices.contains(row) && overviewHeatmap[row].indices.contains(col) ? overviewHeatmap[row][col] : 0
                            let tooltip = heatmapTooltip(for: row, col: col, seconds: seconds)
                            let isFuture = tooltip.isEmpty
                            RoundedRectangle(cornerRadius: 3)
                                .fill(heatmapColor(for: seconds))
                                .frame(width: 14, height: 14)
                                .help(tooltip)
                                .accessibilityLabel(isFuture ? Text("") : Text(tooltip))
                                .accessibilityHidden(isFuture)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Focus activity, last 12 weeks")

            Text("Last 12 weeks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func heatmapColor(for seconds: Int) -> some ShapeStyle {
        if seconds == 0 { return AnyShapeStyle(.quaternary.opacity(0.3)) }
        // Quantize based on fixed hour bands: < 1h, < 2h, < 4h, >= 4h
        if seconds < 3600 { return AnyShapeStyle(Color.accentColor.opacity(0.15)) }
        if seconds < 7200 { return AnyShapeStyle(Color.accentColor.opacity(0.35)) }
        if seconds < 14400 { return AnyShapeStyle(Color.accentColor.opacity(0.60)) }
        return AnyShapeStyle(Color.accentColor.opacity(0.90))
    }

    private func heatmapTooltip(for row: Int, col: Int, seconds: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstWeekday = calendar.firstWeekday
        let endRow = (calendar.component(.weekday, from: today) - firstWeekday + 7) % 7
        let totalDays = 11 * 7 + endRow

        let cellIndex = col * 7 + row
        let offset = cellIndex - totalDays

        if offset > 0 { return "" }
        guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let dateString = formatter.string(from: date)

        let timeString = seconds == 0 ? "No focus" : DurationFormatter.compact(seconds)
        return "\(dateString) — \(timeString)"
    }

    // MARK: - Charts

    private var chartsSection: some View {
        HStack(spacing: Theme.Spacing.xxl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Focus Time by Tag")
                    .font(Theme.Typography.sectionHeader)
                tagChart
                    .frame(height: 160)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Best Hours")
                    .font(Theme.Typography.sectionHeader)
                bestHoursChart
                    .frame(height: 160)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var tagChart: some View {
        Chart {
            ForEach(Array(overviewPerTag.enumerated()), id: \.offset) { _, bucket in
                let title: String = {
                    switch bucket.label {
                    case .named:
                        return tag(for: bucket.tagID)?.title ?? "Unknown"
                    case .other:
                        return "Other"
                    case .noTag:
                        return "No Tag"
                    }
                }()
                let color: Color = {
                    switch bucket.label {
                    case .named:
                        return Color.tag(tag(for: bucket.tagID)?.colorName ?? "blue")
                    case .other, .noTag:
                        return Color.secondary
                    }
                }()

                BarMark(
                    x: .value("Focus Time (hours)", Double(bucket.seconds) / 3600.0),
                    y: .value("Tag", title)
                )
                .foregroundStyle(color)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                if let val = value.as(Double.self) {
                    AxisValueLabel { Text("\(val, specifier: "%.1f")h") }
                }
            }
        }
        .animation(reduceMotion ? nil : .default, value: overviewPerTag.map { $0.seconds })
    }

    private var bestHoursChart: some View {
        Chart {
            ForEach(0..<24, id: \.self) { hour in
                let seconds = overviewBestHours.indices.contains(hour) ? overviewBestHours[hour] : 0
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Focus Time (hours)", Double(seconds) / 3600.0)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                if let val = value.as(Double.self) {
                    AxisValueLabel { Text("\(val, specifier: "%.1f")h") }
                }
            }
        }
        .animation(reduceMotion ? nil : .default, value: overviewBestHours)
    }

    // MARK: - Sessions Chart

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

    private var groupedRecords: [(day: Date, records: [SessionRecord])] {
        StatisticsCalculator.grouped(records: filteredRecords)
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

// MARK: - Goal Tile

private struct GoalTile: View {
    var title: String
    var focusSeconds: Int
    var goalSeconds: Int
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(formatGoalText(focusSeconds)) of \(formatGoalText(goalSeconds))")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ProgressView(value: min(progress, 1.0))
                .progressViewStyle(.linear)
                .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func formatGoalText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        if m > 0 { return "\(m)m" }
        return "0m"
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
