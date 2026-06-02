import SwiftUI

struct ServiceEndpointSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            content
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ServiceJSONItemCard: View {
    let item: ServiceJSONObject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.primaryText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let secondary = item.secondaryText, !secondary.isEmpty {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(Array(item.detailPairs.prefix(5).enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 8) {
                        Text(pair.0)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(pair.1)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ServiceEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

struct MembershipStateRow: View {
    let isMember: Bool?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var title: String {
        guard let isMember else {
            return NSLocalizedString("services_activities_checking_status", comment: "")
        }
        return isMember ? NSLocalizedString("services_activities_member", comment: "") : NSLocalizedString("services_activities_not_member", comment: "")
    }

    private var iconName: String {
        guard let isMember else {
            return "clock"
        }
        return isMember ? "checkmark.circle.fill" : "minus.circle.fill"
    }

    private var iconColor: Color {
        guard let isMember else {
            return .orange
        }
        return isMember ? .green : .secondary
    }

    private var backgroundColor: Color {
        guard let isMember else {
            return .orange.opacity(0.12)
        }
        return isMember ? .green.opacity(0.14) : Color(uiColor: .tertiarySystemGroupedBackground)
    }
}

extension LibraryNewsEntry {
    var displayDate: String {
        if let parsed = LibraryNewsEntry.inputDateFormatter.date(from: date) {
            return LibraryNewsEntry.outputDateFormatter.string(from: parsed)
        }
        return date
    }

    static let inputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static let outputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
