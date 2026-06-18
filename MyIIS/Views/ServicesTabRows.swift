import SwiftUI

struct ServicesSignInPromptRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("services_sign_in_title", comment: ""))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(NSLocalizedString("services_sign_in_subtitle", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

struct ServicesLockedHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.rectangle.stack.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("services_account_locked_title", comment: ""))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(NSLocalizedString("services_account_locked_subtitle", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ServicesLockedRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )

            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Image(systemName: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
