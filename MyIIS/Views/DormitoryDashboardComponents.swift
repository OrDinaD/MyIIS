import SwiftUI

struct DormitoryRejectedApplicationCard: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(dormitoryLocalized("dormitory_application_rejected"), systemImage: "exclamationmark.triangle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.red)

            Text(
                application.rejectionReason?.isEmpty == false
                    ? application.rejectionReason ?? ""
                    : dormitoryLocalized("dormitory_rejection_no_reason")
            )
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            DormitoryApplicationActions(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: onEditApplication,
                onDownloadApplicationForm: {}
            )

            DormitoryTechnicalApplicationLabel(application: application)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.red.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

struct DormitoryApplicationActions: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void
    let onDownloadApplicationForm: () -> Void

    private var hasActions: Bool {
        application.hasDocument || application.canEdit || application.canDownloadApplicationForm
    }

    @ViewBuilder
    var body: some View {
        if hasActions {
            VStack(spacing: 10) {
                if application.hasDocument {
                    DormitoryLabeledActionButton(
                        title: dormitoryLocalized("dormitory_open_attachment"),
                        systemImage: "paperclip",
                        isDisabled: isDownloadingFile,
                        action: onOpenDocument
                    )
                }

                if application.canEdit {
                    DormitoryLabeledActionButton(
                        title: dormitoryLocalized("dormitory_edit_application"),
                        systemImage: "square.and.pencil",
                        isDisabled: false,
                        action: onEditApplication
                    )
                }

                if application.canDownloadApplicationForm {
                    DormitoryLabeledActionButton(
                        title: dormitoryLocalized("dormitory_open_application_form"),
                        systemImage: "arrow.down.doc",
                        isDisabled: isDownloadingFile,
                        action: onDownloadApplicationForm
                    )
                }
            }
        }
    }
}

private struct DormitoryLabeledActionButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .dormitoryActionButtonStyle()
        .disabled(isDisabled)
    }
}

struct DormitoryTechnicalApplicationLabel: View {
    let application: DormitoryQueueApplication

    var body: some View {
        Text(
            String(
                format: dormitoryLocalized("dormitory_application_number"),
                application.number
            )
        )
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}

struct DormitoryApplicationAvailability: View {
    let canCreateApplication: Bool
    let isSubmittingApplication: Bool
    let hasApplications: Bool
    let onCreateApplication: () -> Void

    var body: some View {
        if canCreateApplication {
            Button(action: onCreateApplication) {
                Label(dormitoryLocalized("dormitory_create_application"), systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .dormitoryProminentButtonStyle()
            .controlSize(.large)
            .disabled(isSubmittingApplication)
        } else if hasApplications {
            Label(dormitoryLocalized("dormitory_new_application_unavailable"), systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
    }
}

struct DormitoryHistorySection: View {
    let applications: [DormitoryQueueApplication]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
                    DormitoryHistoryRow(application: application)

                    if index < applications.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)

                Text(dormitoryLocalized("dormitory_history"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(applications.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
        }
        .tint(.secondary)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct DormitoryHistoryRow: View {
    let application: DormitoryQueueApplication

    private var year: String {
        guard let date = application.presentationDate else { return "—" }
        return String(Calendar.autoupdatingCurrent.component(.year, from: date))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(year)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                if let roomInfo = application.roomInfo, !roomInfo.isEmpty {
                    Text(roomInfo)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(
                        String(
                            format: dormitoryLocalized("dormitory_application_number"),
                            application.number
                        )
                    )
                    .font(.subheadline.weight(.semibold))
                }

                if let date = application.presentationDate {
                    Text(dormitoryDateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            DormitoryStatusTag(status: application.status)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct DormitoryEmptyApplicationsCard: View {
    var body: some View {
        ContentUnavailableView(
            dormitoryLocalized("dormitory_no_applications"),
            systemImage: "building.2",
            description: Text(dormitoryLocalized("dormitory_no_applications_description"))
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

extension View {
    @ViewBuilder
    func dormitoryPlaceTileStyle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                .regular.tint(.white.opacity(0.08)),
                in: .rect(cornerRadius: 18)
            )
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
    }

    @ViewBuilder
    func dormitoryActionButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func dormitoryHeroButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass(.clear))
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func dormitoryProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

#if DEBUG
#Preview("Моё место") {
    NavigationStack {
        ScrollView {
            DormitoryApplicationsDashboard(
                announcement: nil,
                applications: Array(DormitoryQueueApplication.preview.dropFirst().prefix(2)),
                canCreateApplication: false,
                isSubmittingApplication: false,
                isDownloadingFile: false,
                onCreateApplication: {},
                onOpenDocument: { _ in },
                onEditApplication: { _ in },
                onDownloadApplicationForm: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Общежитие")
    }
}

#Preview("Заявка обрабатывается") {
    NavigationStack {
        ScrollView {
            DormitoryApplicationsDashboard(
                announcement: nil,
                applications: Array(DormitoryQueueApplication.preview.prefix(1)),
                canCreateApplication: false,
                isSubmittingApplication: false,
                isDownloadingFile: false,
                onCreateApplication: {},
                onOpenDocument: { _ in },
                onEditApplication: { _ in },
                onDownloadApplicationForm: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Общежитие")
    }
}
#endif
