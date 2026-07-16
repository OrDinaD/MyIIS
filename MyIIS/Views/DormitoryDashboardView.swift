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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dormitoryLocalized("dormitory_current_application"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(application.status)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                DormitoryStatusTag(status: application.status)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let queueNumber = application.numberInQueue {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("№\(queueNumber)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(dormitoryLocalized("dormitory_queue_position"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            DormitoryApplicationTimeline(currentStep: application.presentationState.progressStep)

            DormitoryApplicationDates(application: application)

            DormitoryApplicationActions(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: onEditApplication,
                onDownloadApplicationForm: onDownloadApplicationForm
            )

            DormitoryTechnicalApplicationLabel(application: application)
        }
        .padding(18)
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

private struct DormitoryApplicationTimeline: View {
    let currentStep: Int

    private let stages = [
        ("doc.text.fill", "dormitory_stage_submitted"),
        ("checkmark.seal.fill", "dormitory_stage_documents"),
        ("key.horizontal.fill", "dormitory_stage_place"),
        ("house.fill", "dormitory_stage_settled")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 3)
                .padding(.horizontal, 32)
                .padding(.top, 17)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    VStack(spacing: 8) {
                        Image(systemName: stage.0)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(index <= currentStep ? Color.white : Color.secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                index <= currentStep ? Color.blue : Color.secondary.opacity(0.14),
                                in: Circle()
                            )

                        Text(dormitoryLocalized(stage.1))
                            .font(.caption2)
                            .foregroundStyle(index <= currentStep ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct DormitoryApplicationDates: View {
    let application: DormitoryQueueApplication

    var body: some View {
        VStack(spacing: 10) {
            if let applicationDate = application.applicationDate {
                DormitoryInfoRow(
                    title: dormitoryLocalized("dormitory_label_app_date"),
                    value: dormitoryDateFormatter.string(from: applicationDate)
                )
            }

            if let acceptedDate = application.acceptedDate {
                DormitoryInfoRow(
                    title: dormitoryLocalized("dormitory_label_accepted_date"),
                    value: dormitoryDateFormatter.string(from: acceptedDate)
                )
            }

            if let settledDate = application.settledDate {
                DormitoryInfoRow(
                    title: dormitoryLocalized("dormitory_label_settle_date"),
                    value: dormitoryDateFormatter.string(from: settledDate)
                )
            }
        }
    }
}

private struct DormitoryInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
