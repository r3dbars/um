import SwiftUI

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

    // MARK: - Summary

    private var summaryStats: some View {
        HStack(spacing: 16) {
            statBlock(
                label: "Avg Rate",
                value: String(format: "%.1f/min", store.averageRate)
            )
            statBlock(
                label: "Last 5 Avg",
                value: String(format: "%.1f/min", store.averageRate(last: 5))
            )
            statBlock(
                label: "Total Time",
                value: formattedTotalTime
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
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
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    // MARK: - Session list

    private var sessionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.sessions.reversed()) { session in
                    sessionRow(session)
                    Divider().padding(.leading, 16)
                }
            }
        }
        .frame(maxHeight: 280)
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
    }

    private func rateColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<3: return .green
        case 3..<8: return .orange
        default: return .red
        }
    }

    // MARK: - Empty state

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
