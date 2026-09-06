import SwiftUI

extension RatingView {
    @ViewBuilder
    var deadlinesSection: some View {
        Section {
            ForEach(viewModel.deadlineItems) { item in
                disciplineDeadlineRow(for: item)
            }
        } header: {
            HStack {
                Text(NSLocalizedString("performance_deadlines_title", comment: ""))
                Spacer()
                let totalOverdue = viewModel.deadlineItems.reduce(0) { $0 + $1.overdueDeadlines.count }
                if totalOverdue > 0 {
                    Text("\(totalOverdue) просрочено")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func disciplineDeadlineRow(for item: DisciplineDeadlineItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.discipline)
                        .font(.headline)
                    if let fullName = item.fullDisciplineName, fullName != item.discipline {
                        Text(fullName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let total = item.total, total > 0 {
                    Text(String(format: NSLocalizedString("performance_lab_progress_format", comment: ""), Int64(item.submitted), Int64(total)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.allSubmitted ? .green : .secondary)
                        .monospacedDigit()
                } else {
                    Text(String(format: NSLocalizedString("performance_lab_progress_simple", comment: ""), Int64(item.submitted)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if let total = item.total, total > 0 {
                ProgressView(value: Double(min(item.submitted, total)), total: Double(total))
                    .tint(item.allSubmitted ? .green : (item.urgencyStatus == .critical ? .red : .blue))
            }

            HStack(spacing: 8) {
                if item.allSubmitted {
                    Label(NSLocalizedString("performance_all_submitted", comment: ""), systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.green)
                } else if item.deadlinesMissing {
                    Label(NSLocalizedString("performance_no_deadlines", comment: ""), systemImage: "calendar.badge.clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let nearest = item.nearestDeadline {
                    let taskSuffix = item.nearestDeadlineTaskNumber.map { " (№ \($0))" } ?? ""
                    HStack(spacing: 4) {
                        Image(systemName: item.urgencyStatus.iconName)
                        Text(String(format: NSLocalizedString("performance_nearest_deadline_format", comment: ""), "\(nearest)\(taskSuffix)"))
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(item.urgencyStatus.tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.urgencyStatus.tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Spacer()
            }

            if !item.overdueDeadlines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.overdueDeadlines) { overdue in
                        let taskSuffix = overdue.taskNumber.map { " (№ \($0))" } ?? ""
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("\(NSLocalizedString("performance_overdue_prefix", comment: "")) \(overdue.date)\(taskSuffix)")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var checkpointsRatingSection: some View {
        Section(NSLocalizedString("rating_section_missed", comment: "")) {
            HStack {
                Text(NSLocalizedString("rating_total_semester", comment: ""))
                Spacer()
                Text("\(formattedMissed(viewModel.students.first?.missedHours)) ч")
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }

            if !viewModel.checkpointSummaries.isEmpty {
                ForEach(viewModel.checkpointSummaries) { summary in
                    checkpointSummaryRow(summary)
                }
            } else if viewModel.userCheckpoints.isEmpty {
                Text(NSLocalizedString("rating_checkpoints_not_found", comment: ""))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.userCheckpoints) { checkpoint in
                    HStack {
                        if let title = checkpoint.title, !title.isEmpty {
                            Text(title)
                                .fontWeight(.medium)
                        } else {
                            Text(String(format: NSLocalizedString("rating_checkpoint_format", comment: ""), Int64(checkpoint.number)))
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text(formattedGrade(checkpoint.averageGrade))
                            .foregroundStyle(gradeTint(checkpoint.averageGrade))
                            .monospacedDigit()
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(formattedMissed(checkpoint.missedHours)) ч")
                            .foregroundStyle(checkpointMissedTint(checkpoint.missedHours))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checkpointSummaryRow(_ item: CheckpointSummaryItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if item.isTotal {
                    Text(NSLocalizedString("performance_checkpoint_total", comment: ""))
                        .font(.body.weight(.bold))
                } else if let number = item.number {
                    Text(String(format: NSLocalizedString("rating_checkpoint_format", comment: ""), Int64(number)))
                        .font(.body.weight(.medium))
                    Text(item.date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.date)
                        .font(.body.weight(.medium))
                }
            }

            Spacer()

            if let delta = item.delta, delta != 0 {
                HStack(spacing: 2) {
                    Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                    Text(String(format: "%+.2f", delta))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(delta > 0 ? .green : .red)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background((delta > 0 ? Color.green : Color.red).opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            if item.submittedLabs > 0 {
                Text(String(format: NSLocalizedString("performance_checkpoint_labs_format", comment: ""), Int64(item.submittedLabs)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(formattedGrade(item.averageGrade))
                .font(item.isTotal ? .body.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(gradeTint(item.averageGrade))
                .monospacedDigit()

            Text("·")
                .foregroundStyle(.tertiary)

            Text("\(item.absences) ч")
                .font(.subheadline)
                .foregroundStyle(checkpointMissedTint(item.absences))
                .monospacedDigit()
        }
        .padding(.vertical, item.isTotal ? 4 : 2)
    }

    func formattedGrade(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    func formattedMissed(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    func formattedAttemptDate(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return RatingDateTextFormatter.format(value)
    }

    func attemptTypeTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    func gradeTint(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        switch value {
        case 9...:
            return .green
        case 7 ..< 9:
            return .mint
        case 5 ..< 7:
            return .orange
        default:
            return .red
        }
    }

    func checkpointMissedTint(_ value: Int?) -> Color {
        guard let value else { return .secondary }
        if value == 0 { return .green }
        if value <= 2 { return .orange }
        return .red
    }
}

enum RatingDateTextFormatter {
    static func format(_ rawValue: String) -> String {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "—" }

        if let parsed = parse(raw) {
            return outputFormatter.string(from: parsed)
        }

        return raw
    }

    private static func parse(_ raw: String) -> Date? {
        if raw.allSatisfy(\.isNumber), let timestamp = Double(raw) {
            let timeInterval = raw.count >= 13 ? timestamp / 1000 : timestamp
            return Date(timeIntervalSince1970: timeInterval)
        }

        for formatter in directFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }

        for formatter in isoFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }

        return nil
    }

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let directFormatters: [DateFormatter] = [
        makeFormatter("dd.MM.yyyy"),
        makeFormatter("yyyy-MM-dd"),
        makeFormatter("yyyyMMdd"),
        makeFormatter("ddMMyyyy"),
        makeFormatter("yyyy-MM-dd HH:mm:ss"),
        makeFormatter("yyyy-MM-dd'T'HH:mm:ss")
    ]

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [basic, withFractional]
    }()

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
