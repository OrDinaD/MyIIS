import SwiftUI
import UIKit

struct DormitoryFullPageScreenshotBridge: UIViewControllerRepresentable {
    let applications: [DormitoryQueueApplication]
    let privilegeRecords: [DormitoryPrivilegeRecord]

    func makeCoordinator() -> Coordinator {
        Coordinator(
            snapshot: DormitoryScreenshotSnapshot(
                applications: applications,
                privilegeRecords: privilegeRecords
            )
        )
    }

    func makeUIViewController(context: Context) -> DormitoryScreenshotViewController {
        let viewController = DormitoryScreenshotViewController()
        viewController.screenshotDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(
        _ viewController: DormitoryScreenshotViewController,
        context: Context
    ) {
        context.coordinator.snapshot = DormitoryScreenshotSnapshot(
            applications: applications,
            privilegeRecords: privilegeRecords
        )
        viewController.screenshotDelegate = context.coordinator
        viewController.attachToScreenshotService()
    }

    static func dismantleUIViewController(
        _ viewController: DormitoryScreenshotViewController,
        coordinator: Coordinator
    ) {
        viewController.detachFromScreenshotService()
    }

    @MainActor
    final class Coordinator: NSObject, UIScreenshotServiceDelegate {
        var snapshot: DormitoryScreenshotSnapshot

        init(snapshot: DormitoryScreenshotSnapshot) {
            self.snapshot = snapshot
        }

        func screenshotService(
            _ screenshotService: UIScreenshotService,
            generatePDFRepresentationWithCompletion completionHandler: @escaping (Data?, Int, CGRect) -> Void
        ) {
            let data = DormitoryFullPagePDFRenderer.render(
                snapshot: snapshot,
                generatedAt: Date()
            )
            completionHandler(data, 0, .zero)
        }
    }
}

@MainActor
final class DormitoryScreenshotViewController: UIViewController {
    weak var screenshotDelegate: (any UIScreenshotServiceDelegate)?

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachToScreenshotService()
    }

    func attachToScreenshotService() {
        guard let screenshotService = viewIfLoaded?.window?.windowScene?.screenshotService else {
            return
        }
        screenshotService.delegate = screenshotDelegate
    }

    func detachFromScreenshotService() {
        guard
            let screenshotService = viewIfLoaded?.window?.windowScene?.screenshotService,
            screenshotService.delegate === screenshotDelegate
        else {
            return
        }
        screenshotService.delegate = nil
    }
}

struct DormitoryScreenshotSnapshot {
    let applications: [DormitoryQueueApplication]
    let privilegeRecords: [DormitoryPrivilegeRecord]
}

@MainActor
enum DormitoryFullPagePDFRenderer {
    private static let pageWidth: CGFloat = 612

    static func render(
        snapshot: DormitoryScreenshotSnapshot,
        generatedAt: Date
    ) -> Data? {
        let content = DormitoryFullPageSnapshotView(
            snapshot: snapshot,
            generatedAt: generatedAt
        )
        .environment(\.colorScheme, .light)

        let imageRenderer = ImageRenderer(content: content)
        imageRenderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)

        var pdfData: Data?
        imageRenderer.render { size, render in
            guard size.width > 0, size.height > 0 else { return }

            let bounds = CGRect(
                origin: .zero,
                size: CGSize(width: pageWidth, height: size.height)
            )
            let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds)
            pdfData = pdfRenderer.pdfData { context in
                context.beginPage()
                context.cgContext.translateBy(x: 0, y: bounds.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                render(context.cgContext)
            }
        }
        return pdfData
    }
}

private struct DormitoryFullPageSnapshotView: View {
    let snapshot: DormitoryScreenshotSnapshot
    let generatedAt: Date

    private var applications: [DormitoryQueueApplication] {
        snapshot.applications.sorted {
            ($0.applicationDate ?? .distantPast) > ($1.applicationDate ?? .distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            VStack(alignment: .leading, spacing: 14) {
                DormitorySnapshotSectionTitle(
                    title: dormitoryLocalized("dormitory_full_page_applications"),
                    systemImage: "building.2.fill"
                )

                if applications.isEmpty {
                    Text(dormitoryLocalized("dormitory_no_applications"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ForEach(applications) { application in
                        DormitoryFullPageApplicationCard(application: application)
                    }
                }
            }

            if !snapshot.privilegeRecords.isEmpty {
                privileges
            }

            footer
        }
        .padding(36)
        .frame(width: 612, alignment: .leading)
        .background(Color.white)
        .environment(\.locale, .autoupdatingCurrent)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(dormitoryLocalized("dormitory_full_page_title"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(dormitoryLocalized("dormitory_full_page_subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privileges: some View {
        VStack(alignment: .leading, spacing: 14) {
            DormitorySnapshotSectionTitle(
                title: dormitoryLocalized("dormitory_full_page_privileges"),
                systemImage: "star.circle.fill"
            )

            VStack(spacing: 0) {
                ForEach(Array(snapshot.privilegeRecords.enumerated()), id: \.element.id) { index, record in
                    HStack(spacing: 16) {
                        Text(String(record.year))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .leading)

                        Text(record.dormitoryPrivilegeCategoryName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)

                    if index < snapshot.privilegeRecords.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text(
                String(
                    format: dormitoryLocalized("dormitory_full_page_generated"),
                    generatedAt.formatted(date: .numeric, time: .standard)
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("MyIIS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct DormitorySnapshotSectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
    }
}

private struct DormitoryFullPageApplicationCard: View {
    let application: DormitoryQueueApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        String(
                            format: dormitoryLocalized("dormitory_application_number"),
                            application.number
                        )
                    )
                    .font(.title3.weight(.bold))

                    if let roomInfo = application.roomInfo, !roomInfo.isEmpty {
                        Text(roomInfo)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                DormitoryStatusTag(status: application.status)
            }

            Divider()

            VStack(spacing: 10) {
                DormitorySnapshotValueRow(
                    title: dormitoryLocalized("dormitory_label_status"),
                    value: application.status
                )

                if let applicationDate = application.applicationDate {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_app_date"),
                        value: dormitoryDateFormatter.string(from: applicationDate)
                    )
                }

                if let acceptedDate = application.acceptedDate {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_accepted_date"),
                        value: dormitoryDateFormatter.string(from: acceptedDate)
                    )
                }

                if let settledDate = application.settledDate {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_settle_date"),
                        value: dormitoryDateFormatter.string(from: settledDate)
                    )
                }

                if let queueNumber = application.numberInQueue {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_queue_number"),
                        value: String(queueNumber)
                    )
                }

                if let roomInfo = application.roomInfo, !roomInfo.isEmpty {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_room"),
                        value: roomInfo
                    )
                }

                if let rejectionReason = application.rejectionReason, !rejectionReason.isEmpty {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_reason"),
                        value: rejectionReason
                    )
                }

                if let document = application.docReference, !document.isEmpty {
                    DormitorySnapshotValueRow(
                        title: dormitoryLocalized("dormitory_label_document"),
                        value: document
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DormitoryStatusTag(status: application.status).tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DormitorySnapshotValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("Вся страница") {
    ScrollView {
        DormitoryFullPageSnapshotView(
            snapshot: DormitoryScreenshotSnapshot(
                applications: DormitoryQueueApplication.preview,
                privilegeRecords: DormitoryPrivilegeRecord.preview
            ),
            generatedAt: .now
        )
    }
}
#endif
