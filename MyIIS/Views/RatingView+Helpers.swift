import SwiftUI

extension RatingView {
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

            if viewModel.userCheckpoints.isEmpty {
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
