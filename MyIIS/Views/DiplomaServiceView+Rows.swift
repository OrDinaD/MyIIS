import SwiftUI

struct SectionTitle: View {
    let title: String
    let required: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if required {
                Text("*")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }
}

struct SelectedSupervisorView: View {
    let supervisor: DiplomaSupervisor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: supervisor.isExternal ? "person.crop.square" : "building.columns.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(supervisor.title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle = supervisor.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SupervisorResultRow: View {
    let supervisor: DiplomaSupervisor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: supervisor.isExternal ? "person.crop.square" : "building.columns.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(supervisor.isExternal ? .orange : .blue)
                .frame(width: 30, height: 30)
                .background((supervisor.isExternal ? Color.orange : Color.blue).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(supervisor.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle = supervisor.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DiplomaServiceView()
    }
}
