import Combine
import CoreMotion
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
        case .settled:
            if application.placement != nil {
                DormitoryPlaceHero(
                    application: application,
                    isDownloadingFile: isDownloadingFile,
                    onOpenDocument: onOpenDocument
                )
            } else {
                DormitoryStatusCard(
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
        case .waiting, .documentsAccepted, .readyToSettle, .unknown:
            DormitoryStatusCard(
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DormitoryFacadePattern()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(application.status, systemImage: "house.fill")
                            .font(.title2.weight(.bold))

                        if let settledDate = application.settledDate {
                            Text(
                                String(
                                    format: dormitoryLocalized("dormitory_settled_since"),
                                    dormitoryDateFormatter.string(from: settledDate)
                                )
                            )
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
                    Color(red: 0.02, green: 0.45, blue: 0.36),
                    Color(red: 0.02, green: 0.62, blue: 0.46),
                    Color(red: 0.04, green: 0.72, blue: 0.61)
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
        .shadow(color: Color.green.opacity(0.18), radius: 20, y: 10)
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

private struct DormitoryStatusCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var motion = DormitoryCardMotion()

    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void
    let onDownloadApplicationForm: () -> Void

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

    private var statusColors: [Color] {
        switch application.presentationState {
        case .settled:
            return [
                Color(red: 0.02, green: 0.45, blue: 0.36),
                Color(red: 0.02, green: 0.62, blue: 0.46),
                Color(red: 0.04, green: 0.72, blue: 0.61)
            ]
        case .readyToSettle:
            return [
                Color(red: 0.31, green: 0.18, blue: 0.78),
                Color(red: 0.46, green: 0.26, blue: 0.92),
                Color(red: 0.60, green: 0.39, blue: 0.98)
            ]
        case .evicted:
            return [
                Color(red: 0.30, green: 0.32, blue: 0.37),
                Color(red: 0.43, green: 0.45, blue: 0.51),
                Color(red: 0.55, green: 0.57, blue: 0.63)
            ]
        case .rejected:
            return [
                Color(red: 0.66, green: 0.07, blue: 0.15),
                Color(red: 0.84, green: 0.12, blue: 0.20),
                Color(red: 0.94, green: 0.24, blue: 0.27)
            ]
        case .waiting, .documentsAccepted, .unknown:
            return [
                Color(red: 0.04, green: 0.29, blue: 0.88),
                Color(red: 0.04, green: 0.47, blue: 0.96),
                Color(red: 0.12, green: 0.64, blue: 0.98)
            ]
        }
    }

    private var statusAccent: Color {
        statusColors[1]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: statusColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            DormitoryMotionShimmer(
                horizontal: motion.horizontal,
                vertical: motion.vertical
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.title2.weight(.bold))
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.16), in: Circle())

                    Text(application.status)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    if let applicationDate = application.applicationDate {
                        DormitoryStatusFact(
                            text: String(
                                format: dormitoryLocalized("dormitory_compact_submitted"),
                                dormitoryDateFormatter.string(from: applicationDate)
                            ),
                            systemImage: "calendar.badge.plus"
                        )

                        DormitoryStatusFactDivider()
                    }

                    if let acceptedDate = application.acceptedDate {
                        DormitoryStatusFact(
                            text: String(
                                format: dormitoryLocalized("dormitory_compact_accepted"),
                                dormitoryDateFormatter.string(from: acceptedDate)
                            ),
                            systemImage: "checkmark.circle.fill"
                        )

                        DormitoryStatusFactDivider()
                    }

                    if let settledDate = application.settledDate {
                        DormitoryStatusFact(
                            text: String(
                                format: dormitoryLocalized("dormitory_compact_settled"),
                                dormitoryDateFormatter.string(from: settledDate)
                            ),
                            systemImage: "house.fill"
                        )

                        DormitoryStatusFactDivider()
                    }

                    DormitoryStatusFact(
                        text: String(
                            format: dormitoryLocalized("dormitory_application_number"),
                            application.number
                        ),
                        systemImage: "number"
                    )

                    if let queueNumber = application.numberInQueue {
                        DormitoryStatusFactDivider()

                        DormitoryStatusFact(
                            text: String(
                                format: dormitoryLocalized("dormitory_queue_compact"),
                                queueNumber
                            ),
                            systemImage: "person.line.dotted.person.fill"
                        )
                    }

                    if let roomInfo = application.roomInfo, !roomInfo.isEmpty {
                        DormitoryStatusFactDivider()
                        DormitoryStatusFact(text: roomInfo, systemImage: "building.2.fill")
                    }
                }
                .background(
                    .white.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                DormitoryApplicationActions(
                    application: application,
                    isDownloadingFile: isDownloadingFile,
                    onOpenDocument: onOpenDocument,
                    onEditApplication: onEditApplication,
                    onDownloadApplicationForm: onDownloadApplicationForm
                )
                .tint(.white)
                .foregroundStyle(.white)
            }
            .padding(20)
        }
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: statusAccent.opacity(0.22), radius: 18, y: 9)
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : -motion.vertical * 4.5),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.28
        )
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : motion.horizontal * 5.5),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.28
        )
        .animation(.linear(duration: 0.1), value: motion.horizontal)
        .animation(.linear(duration: 0.1), value: motion.vertical)
        .accessibilityElement(children: .contain)
        .onAppear {
            updateMotion()
        }
        .onDisappear {
            motion.stop()
        }
        .onChange(of: scenePhase) {
            updateMotion()
        }
        .onChange(of: reduceMotion) {
            updateMotion()
        }
    }

    private func updateMotion() {
        if scenePhase == .active && !reduceMotion {
            motion.start()
        } else {
            motion.stop()
        }
    }
}

private struct DormitoryStatusFact: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

private struct DormitoryStatusFactDivider: View {
    var body: some View {
        Divider()
            .overlay(.white.opacity(0.16))
            .padding(.leading, 43)
    }
}

private struct DormitoryMotionShimmer: View {
    let horizontal: Double
    let vertical: Double

    var body: some View {
        GeometryReader { proxy in
            RadialGradient(
                colors: [
                    .white.opacity(0.22),
                    .white.opacity(0.06),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 90
            )
            .frame(width: 180, height: 180)
            .position(
                x: proxy.size.width * (0.5 + horizontal * 0.34),
                y: proxy.size.height * (0.42 + vertical * 0.24)
            )
            .blur(radius: 7)
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class DormitoryCardMotion: ObservableObject {
    @Published private(set) var horizontal = 0.0
    @Published private(set) var vertical = 0.0

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else {
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }

            let horizontal = Self.clamped(motion.attitude.roll / 0.65)
            let vertical = Self.clamped(motion.attitude.pitch / 0.65)

            Task { @MainActor [weak self] in
                self?.horizontal = horizontal
                self?.vertical = vertical
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        horizontal = 0
        vertical = 0
    }

    nonisolated private static func clamped(_ value: Double) -> Double {
        min(max(value, -1), 1)
    }
}
