import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject private var store = SessionStore.shared

    var body: some View {
        VStack(spacing: 0) {
            historyHeader
            Divider()
            if store.sessions.isEmpty {
                emptyHistory
            } else {
                summaryStats
                Divider()
                trendChart
                Divider()
                sessionList
            }
        }
        .frame(width: 280)
    }

    // MARK: - Header

    private var historyHeader: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .navigateBack, object: nil)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            Text("History")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            Text("\(store.sessionCount) sessions")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        HStack(spacing: 0) {
            statBlock(
                label: "All-time avg",
                value: String(format: "%.1f/min", store.averageRate)
            )
            Divider().frame(height: 36)
            statBlock(
                label: "Last 5 avg",
                value: String(format: "%.1f/min", store.averageRate(last: 5))
            )
            Divider().frame(height: 36)
            statBlock(
                label: "Total time",
                value: formattedTotalTime
            )
        }
        .padding(.vertical, 10)
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedTotalTime: String {
        let total = Int(store.totalTime)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Rate over time")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                trendBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            let recent = Array(store.sessions.suffix(20))
            if recent.count >= 2 {
                Chart {
                    ForEach(Array(recent.enumerated()), id: \.offset) { i, session in
                        LineMark(
                            x: .value("Session", i),
                            y: .value("Rate", session.ratePerMinute)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Session", i),
                            y: .value("Rate", session.ratePerMinute)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.12))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                        AxisValueLabel()
                            .font(.system(size: 8))
                    }
                }
                .frame(height: 60)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var trendBadge: some View {
        let trend = store.trend(last: 5)
        return Group {
            if trend < -0.5 {
                Label("Improving", systemImage: "arrow.down.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
            } else if trend > 0.5 {
                Label("Getting worse", systemImage: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
            } else {
                Label("Steady", systemImage: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.trailing, 16)
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.sessions.reversed()) { session in
                    sessionRow(session)
                    Divider().padding(.leading, 16)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func sessionRow(_ session: SessionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.formattedDate)
                    .font(.system(size: 12))
                HStack(spacing: 8) {
                    Text(session.formattedDuration)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f/min", session.ratePerMinute))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("\(session.totalCount)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(rateColor(session.ratePerMinute))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteSession(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<3: return .green
        case 3..<8: return .orange
        default: return .red
        }
    }

    // MARK: - Empty State

    private var emptyHistory: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No sessions yet")
                .font(.system(size: 13, weight: .medium))
            Text("Complete a session (5+ seconds)\nto start tracking your progress.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
