import SwiftUI

struct DormitoryApplicationsDashboard: View {
    let announcement: DormitoryAnnouncement?
    let applications: [DormitoryQueueApplication]
    let canCreateApplication: Bool
    let isSubmittingApplication: Bool
    let isDownloadingFile: Bool
    let onCreateApplication: () -> Void
    let onOpenDocument: (DormitoryQueueApplication) -> Void
    let onEditApplication: (DormitoryQueueApplication) -> Void
    let onDownloadApplicationForm: (DormitoryQueueApplication) -> Void

    private var sortedApplications: [DormitoryQueueApplication] {
        applications.sorted {
            ($0.applicationDate ?? .distantPast) > ($1.applicationDate ?? .distantPast)
        }
    }

    private var currentApplication: DormitoryQueueApplication? {
        guard let newest = sortedApplications.first, newest.presentationState != .evicted else {
            return nil
        }
        return newest
    }

    private var historyApplications: [DormitoryQueueApplication] {
        guard let currentApplication else { return sortedApplications }
        return sortedApplications.filter { $0.id != currentApplication.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let currentApplication {
                DormitoryCurrentApplicationCard(
                    application: currentApplication,
                    isDownloadingFile: isDownloadingFile,
                    onOpenDocument: { onOpenDocument(currentApplication) },
                    onEditApplication: { onEditApplication(currentApplication) },
                    onDownloadApplicationForm: { onDownloadApplicationForm(currentApplication) }
                )
            } else if applications.isEmpty {
                DormitoryEmptyApplicationsCard()
            }

            DormitoryApplicationAvailability(
                canCreateApplication: canCreateApplication,
                isSubmittingApplication: isSubmittingApplication,
                hasApplications: !applications.isEmpty,
                onCreateApplication: onCreateApplication
            )

            if let announcement {
                DormitoryAnnouncementCard(announcement: announcement)
            }

            if !historyApplications.isEmpty {
                DormitoryHistorySection(applications: historyApplications)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DormitoryCurrentApplicationCard: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void
    let onDownloadApplicationForm: () -> Void

    @ViewBuilder
    var body: some View {
        switch application.presentationState {
        case .settled, .readyToSettle:
            if application.placement != nil {
                DormitoryPlaceHero(
                    application: application,
                    isDownloadingFile: isDownloadingFile,
                    onOpenDocument: onOpenDocument
                )
            } else {
                DormitoryProgressCard(
                    application: application,
                    isDownloadingFile: isDownloadingFile,
                    onOpenDocument: onOpenDocument,
                    onEditApplication: onEditApplication,
                    onDownloadApplicationForm: onDownloadApplicationForm
                )
            }
        case .rejected:
            DormitoryRejectedApplicationCard(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: onEditApplication
            )
        case .waiting, .documentsAccepted, .unknown:
            DormitoryProgressCard(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: onEditApplication,
                onDownloadApplicationForm: onDownloadApplicationForm
            )
        case .evicted:
            EmptyView()
        }
    }
}

private struct DormitoryPlaceHero: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void

    private var placement: DormitoryPlacement {
        application.placement ?? DormitoryPlacement(
            room: application.roomInfo ?? dormitoryLocalized("dormitory_place_unknown"),
            dormitory: nil
        )
    }

    private var isSettled: Bool {
        application.presentationState == .settled
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DormitoryFacadePattern()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            isSettled ? dormitoryLocalized("dormitory_my_place") : dormitoryLocalized("dormitory_place_assigned"),
                            systemImage: isSettled ? "house.fill" : "key.horizontal.fill"
                        )
                        .font(.title2.weight(.bold))

                        if isSettled, let settledDate = application.settledDate {
                            Text(
                                String(
                                    format: dormitoryLocalized("dormitory_settled_since"),
                                    dormitoryDateFormatter.string(from: settledDate)
                                )
                            )
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                        } else {
                            Text(dormitoryLocalized("dormitory_ready_description"))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }

                    Spacer(minLength: 8)

                    Text(application.status)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.17), in: Capsule())
                }

                DormitoryPlacementTiles(placement: placement)

                if application.hasDocument {
                    Button(action: onOpenDocument) {
                        Label(dormitoryLocalized("dormitory_open_document"), systemImage: "doc.text.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .dormitoryHeroButtonStyle()
                    .disabled(isDownloadingFile)
                }

                Text(
                    String(
                        format: dormitoryLocalized("dormitory_application_number"),
                        application.number
                    )
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.08, blue: 0.16),
                    Color(red: 0.94, green: 0.25, blue: 0.13),
                    Color(red: 0.98, green: 0.43, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.red.opacity(0.2), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
    }
}

private struct DormitoryFacadePattern: View {
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { column in
                    VStack(spacing: 14) {
                        ForEach(0..<5, id: \.self) { row in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white.opacity((column + row).isMultiple(of: 3) ? 0.10 : 0.045))
                                .frame(
                                    width: max(18, (proxy.size.width - 70) / 6),
                                    height: 28
                                )
                        }
                    }
                }
            }
            .rotationEffect(.degrees(-8))
            .offset(x: -12, y: 18)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DormitoryPlacementTiles: View {
    let placement: DormitoryPlacement

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    tiles
                }
            } else {
                tiles
            }
        }
    }

    private var tiles: some View {
        HStack(spacing: 12) {
            if let dormitory = placement.dormitory {
                DormitoryPlaceTile(
                    title: dormitoryLocalized("dormitory_label_dormitory"),
                    value: dormitory
                )
            }

            DormitoryPlaceTile(
                title: dormitoryLocalized("dormitory_label_room"),
                value: placement.room
            )
        }
    }
}

private struct DormitoryPlaceTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.72))

            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .dormitoryPlaceTileStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct DormitoryProgressCard: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void
    let onDownloadApplicationForm: () -> Void

    private var description: String {
        switch application.presentationState {
        case .documentsAccepted:
            return dormitoryLocalized("dormitory_documents_accepted_description")
        case .readyToSettle:
            return dormitoryLocalized("dormitory_ready_description")
        case .settled:
            return dormitoryLocalized("dormitory_settled_without_room_description")
        case .waiting:
            return dormitoryLocalized("dormitory_waiting_description")
        case .unknown:
            return dormitoryLocalized("dormitory_processing_description")
        case .rejected, .evicted:
            return ""
        }
    }

    private var statusIcon: String {
        switch application.presentationState {
        case .waiting:
            return "doc.text.fill"
        case .documentsAccepted:
            return "checkmark.seal.fill"
        case .readyToSettle:
            return "key.horizontal.fill"
        case .settled:
            return "house.fill"
        case .rejected:
            return "exclamationmark.triangle.fill"
        case .evicted:
            return "door.left.hand.open"
        case .unknown:
            return "clock.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(dormitoryLocalized("dormitory_current_application"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(application.status)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DormitoryApplicationProgress(state: application.presentationState)

            if let queueNumber = application.numberInQueue {
                Label(
                    String(
                        format: dormitoryLocalized("dormitory_queue_compact"),
                        queueNumber
                    ),
                    systemImage: "person.line.dotted.person.fill"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(.blue)
            }

            DormitoryApplicationActions(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: onEditApplication,
                onDownloadApplicationForm: onDownloadApplicationForm
            )

            DormitoryApplicationMetadata(application: application)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct DormitoryApplicationProgress: View {
    let state: DormitoryPresentationState

    private let stageKeys = [
        "dormitory_stage_submitted",
        "dormitory_stage_documents",
        "dormitory_stage_place",
        "dormitory_stage_settled"
    ]

    private var step: Int {
        state.progressStep
    }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(step + 1), total: Double(stageKeys.count))
                .tint(.blue)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(
                    String(
                        format: dormitoryLocalized("dormitory_progress_step"),
                        step + 1,
                        stageKeys.count
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if step + 1 < stageKeys.count {
                    Text(
                        String(
                            format: dormitoryLocalized("dormitory_next_step"),
                            dormitoryLocalized(stageKeys[step + 1])
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DormitoryApplicationMetadata: View {
    let application: DormitoryQueueApplication

    private var relevantDate: Date? {
        switch application.presentationState {
        case .waiting:
            return application.applicationDate
        case .documentsAccepted, .readyToSettle:
            return application.acceptedDate ?? application.applicationDate
        case .settled:
            return application.settledDate ?? application.acceptedDate
        case .rejected, .evicted, .unknown:
            return application.presentationDate
        }
    }

    private var dateFormatKey: String {
        switch application.presentationState {
        case .waiting:
            return "dormitory_compact_submitted"
        case .documentsAccepted:
            return "dormitory_compact_accepted"
        case .readyToSettle:
            return "dormitory_compact_ready"
        case .settled:
            return "dormitory_compact_settled"
        case .rejected, .evicted, .unknown:
            return "dormitory_compact_updated"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let relevantDate {
                Label(
                    String(
                        format: dormitoryLocalized(dateFormatKey),
                        dormitoryDateFormatter.string(from: relevantDate)
                    ),
                    systemImage: "calendar"
                )
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            DormitoryTechnicalApplicationLabel(application: application)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .accessibilityElement(children: .combine)
    }
}
