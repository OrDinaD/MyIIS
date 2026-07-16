import SwiftUI
import UIKit

struct QuizTimerBanner: View {
    private let startDate: Date
    private let endDate: Date

    init(remainingSeconds: Int) {
        let now = Date()
        self.startDate = now
        self.endDate = now.addingTimeInterval(TimeInterval(max(remainingSeconds, 0)))
    }

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date)))
            let total = max(1, Int(endDate.timeIntervalSince(startDate)))
            let progress = Double(total - remaining) / Double(total)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "timer")
                    Text("Оставшееся время")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Text(Self.format(remaining))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                .foregroundStyle(.secondary)

                ProgressView(value: progress)
                    .tint(.accentColor)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct HTMLTextBlock: View {
    let html: String

    var body: some View {
        if let attributed = html.toAttributedString() {
            Text(attributed)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(html.strippingSimpleHTML())
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct QuizRemoteImage: View {
    let url: URL
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            CachedAsyncImage(url: url, maxPixelSize: 1_024) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

struct AttemptMetaRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
    }
}

extension String {
    func toAttributedString() -> AttributedString? {
        guard let data = data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let nsAttr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        return try? AttributedString(nsAttr, including: \.foundation)
    }

    func strippingSimpleHTML() -> String {
        replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .decodingHTMLEntities()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var statusColor: Color {
        let normalized = lowercased()
        if normalized.contains("ответ сохран") {
            return Color(uiColor: .systemGreen)
        }
        if normalized.contains("пока нет ответа") {
            return Color(uiColor: .systemYellow)
        }
        if normalized.contains("заверш") {
            return Color(uiColor: .systemGreen)
        }
        if normalized.contains("ошибка") {
            return Color(uiColor: .systemRed)
        }
        return .secondary
    }
}
