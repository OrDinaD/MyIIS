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
        application.hasDocument || application.canDownloadApplicationForm
    }

    @ViewBuilder
    var body: some View {
        if hasActions {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    actionButtons
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if application.hasDocument {
            DormitoryLabeledActionButton(
                title: dormitoryLocalized("dormitory_open_attachment"),
                systemImage: "paperclip",
                isDisabled: isDownloadingFile,
                action: onOpenDocument
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

private struct DormitoryLabeledActionButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
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
        }
    }
}

struct DormitoryHistorySection: View {
    let applications: [DormitoryQueueApplication]
    let isDownloadingFile: Bool
    let onOpenDocument: (DormitoryQueueApplication) -> Void
    let onDownloadApplicationForm: (DormitoryQueueApplication) -> Void
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVStack(spacing: 12) {
                ForEach(applications) { application in
                    DormitoryHistoryRow(
                        application: application,
                        isDownloadingFile: isDownloadingFile,
                        onOpenDocument: { onOpenDocument(application) },
                        onDownloadApplicationForm: { onDownloadApplicationForm(application) }
                    )
                }
            }
            .padding(.top, 12)
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct DormitoryHistoryRow: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onDownloadApplicationForm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(
                    String(
                        format: dormitoryLocalized("dormitory_application_number"),
                        application.number
                    )
                )
                .font(.headline)
                .foregroundStyle(.primary)

                Spacer(minLength: 8)

                DormitoryStatusTag(status: application.status)
            }

            if let placement = application.placement {
                HStack(spacing: 10) {
                    Label(placement.room, systemImage: "door.left.hand.closed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let dormitory = placement.dormitory {
                        DormitoryNumberBadge(number: dormitory)
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 10)],
                alignment: .leading,
                spacing: 8
            ) {
                if let applicationDate = application.applicationDate {
                    DormitoryHistoryFact(
                        text: String(
                            format: dormitoryLocalized("dormitory_compact_submitted"),
                            dormitoryDateFormatter.string(from: applicationDate)
                        ),
                        systemImage: "calendar.badge.plus"
                    )
                }

                if let acceptedDate = application.acceptedDate {
                    DormitoryHistoryFact(
                        text: String(
                            format: dormitoryLocalized("dormitory_compact_accepted"),
                            dormitoryDateFormatter.string(from: acceptedDate)
                        ),
                        systemImage: "checkmark.circle"
                    )
                }

                if let settledDate = application.settledDate {
                    DormitoryHistoryFact(
                        text: String(
                            format: dormitoryLocalized("dormitory_compact_settled"),
                            dormitoryDateFormatter.string(from: settledDate)
                        ),
                        systemImage: "house"
                    )
                }

                if let queueNumber = application.numberInQueue {
                    DormitoryHistoryFact(
                        text: String(
                            format: dormitoryLocalized("dormitory_queue_compact"),
                            queueNumber
                        ),
                        systemImage: "person.line.dotted.person"
                    )
                }
            }

            DormitoryApplicationActions(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: {},
                onDownloadApplicationForm: onDownloadApplicationForm
            )
        }
        .padding(16)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct DormitoryNumberBadge: View {
    let number: String

    private var isRental: Bool {
        let normalized = number.lowercased()
        return normalized.contains("аренд") || normalized.contains("rental")
    }

    private var tint: Color {
        if isRental {
            return .cyan
        }

        switch number.filter(\.isNumber) {
        case "1":
            return .blue
        case "2":
            return .purple
        case "3":
            return .pink
        case "4":
            return .indigo
        case "5":
            return .orange
        case "6":
            return .teal
        default:
            return .mint
        }
    }

    private var title: String {
        if isRental {
            return number
        }
        return "\(dormitoryLocalized("dormitory_label_dormitory")) \(number)"
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct DormitoryHistoryFact: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                onDownloadApplicationForm: { _ in },
                pendingSettlementApplicationID: nil,
                onPresentSettlementReveal: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Общежитие")
    }
}

#Preview("Документы приняты") {
    NavigationStack {
        ScrollView {
            DormitoryApplicationsDashboard(
                announcement: nil,
                applications: [.documentsAcceptedPreview],
                canCreateApplication: false,
                isSubmittingApplication: false,
                isDownloadingFile: false,
                onCreateApplication: {},
                onOpenDocument: { _ in },
                onEditApplication: { _ in },
                onDownloadApplicationForm: { _ in },
                pendingSettlementApplicationID: nil,
                onPresentSettlementReveal: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Общежитие")
    }
}

#Preview("Место выделено") {
    NavigationStack {
        ScrollView {
            DormitoryApplicationsDashboard(
                announcement: nil,
                applications: [.readyToSettlePreview],
                canCreateApplication: false,
                isSubmittingApplication: false,
                isDownloadingFile: false,
                onCreateApplication: {},
                onOpenDocument: { _ in },
                onEditApplication: { _ in },
                onDownloadApplicationForm: { _ in },
                pendingSettlementApplicationID: nil,
                onPresentSettlementReveal: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Общежитие")
    }
}

private extension DormitoryQueueApplication {
    static let documentsAcceptedPreview = DormitoryQueueApplication(
        id: 40_001,
        acceptedDate: DormitoryDateParser.parse("2026-07-16T10:00:00"),
        applicationDate: DormitoryDateParser.parse("2026-07-16T09:00:00"),
        settledDate: nil,
        status: DormitoryApplicationStatus.documentsAccepted.rawValue,
        number: 1,
        numberInQueue: nil,
        docReference: nil,
        docContent: nil,
        rejectionReason: nil,
        roomInfo: nil
    )

    static let readyToSettlePreview = DormitoryQueueApplication(
        id: 40_002,
        acceptedDate: DormitoryDateParser.parse("2026-07-16T10:00:00"),
        applicationDate: DormitoryDateParser.parse("2026-07-16T09:00:00"),
        settledDate: nil,
        status: DormitoryApplicationStatus.readyToSettle.rawValue,
        number: 1,
        numberInQueue: nil,
        docReference: nil,
        docContent: nil,
        rejectionReason: nil,
        roomInfo: "1302-а, Общ.4"
    )
}
#endif
