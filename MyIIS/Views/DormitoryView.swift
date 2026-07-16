import QuickLook
import SwiftUI

struct DormitoryView: View {
    @StateObject private var viewModel: DormitoryViewModel
    @State private var previewURL: URL?
    @State private var editorContext: DormitoryApplicationEditorContext?

    @MainActor
    init(viewModel: DormitoryViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? DormitoryViewModel())
    }

    var body: some View {
        ScrollView {
            dormitoryContent
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .background {
            DormitoryFullPageScreenshotBridge(
                applications: viewModel.applications,
                privilegeRecords: viewModel.privilegeRecords
            )
            .frame(width: 0, height: 0)
        }
        .navigationTitle(NSLocalizedString("dormitory_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .quickLookPreview($previewURL)
        .sheet(item: $editorContext) { context in
            DormitoryApplicationEditorSheet(
                context: context,
                isSubmitting: viewModel.isSubmittingApplication,
                onCancel: { editorContext = nil },
                onCreate: { documentURL in
                    Task {
                        if await viewModel.createApplication(documentURL: documentURL) {
                            editorContext = nil
                        }
                    }
                },
                onOpenExistingDocument: { application in
                    Task {
                        await openDocument(for: application)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(NSLocalizedString("common_error", comment: ""), isPresented: Binding(
            get: { viewModel.actionErrorMessage != nil },
            set: { if !$0 { viewModel.actionErrorMessage = nil } }
        )) {
            Button(NSLocalizedString("common_ok", comment: ""), role: .cancel) {
                viewModel.actionErrorMessage = nil
            }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var dormitoryContent: some View {
        VStack(spacing: 16) {
            if viewModel.isShowingStaleDataWarning {
                StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                    await viewModel.reload()
                }
            }

            if viewModel.isLoading && viewModel.applications.isEmpty && viewModel.privilegeRecords.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("dormitory_loading", comment: ""),
                    systemImage: "building.2",
                    description: Text("Проверяем заявки и льготы.")
                )
            }

            if let error = viewModel.errorMessage,
               viewModel.applications.isEmpty,
               viewModel.privilegeRecords.isEmpty {
                ErrorCard(message: error) {
                    Task { await viewModel.reload() }
                }
            }

            ApplicationsSection(
                announcement: viewModel.announcement,
                applications: viewModel.applications,
                canCreateApplication: viewModel.canCreateApplication,
                isSubmittingApplication: viewModel.isSubmittingApplication,
                isDownloadingFile: viewModel.isDownloadingFile,
                onCreateApplication: {
                    editorContext = .create
                },
                onOpenDocument: { application in
                    Task { await openDocument(for: application) }
                },
                onEditApplication: { application in
                    editorContext = .edit(application)
                },
                onDownloadApplicationForm: { application in
                    Task { await downloadApplicationForm(for: application) }
                }
            )
            PrivilegesSection(records: viewModel.privilegeRecords)
        }
    }

    private func openDocument(for application: DormitoryQueueApplication) async {
        if let fileURL = await viewModel.downloadDocument(for: application) {
            previewURL = fileURL
        }
    }

    private func downloadApplicationForm(for application: DormitoryQueueApplication) async {
        if let fileURL = await viewModel.downloadApplicationForm(for: application) {
            previewURL = fileURL
        }
    }
}

enum DormitoryApplicationEditorContext: Identifiable {
    case create
    case edit(DormitoryQueueApplication)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let application):
            return "edit-\(application.id)"
        }
    }

    var application: DormitoryQueueApplication? {
        if case .edit(let application) = self { return application }
        return nil
    }

    var title: String {
        switch self {
        case .create:
            return "Оформление заявки на общежитие"
        case .edit:
            return "Редактирование заявки на общежитие"
        }
    }

    var submitTitle: String {
        switch self {
        case .create:
            return "Отправить заявку"
        case .edit:
            return "Сохранить изменения"
        }
    }
}

private struct ApplicationsSection: View {
    let announcement: DormitoryAnnouncement?
    let applications: [DormitoryQueueApplication]
    let canCreateApplication: Bool
    let isSubmittingApplication: Bool
    let isDownloadingFile: Bool
    let onCreateApplication: () -> Void
    let onOpenDocument: (DormitoryQueueApplication) -> Void
    let onEditApplication: (DormitoryQueueApplication) -> Void
    let onDownloadApplicationForm: (DormitoryQueueApplication) -> Void

    var body: some View {
        DormitoryApplicationsDashboard(
            announcement: announcement,
            applications: applications,
            canCreateApplication: canCreateApplication,
            isSubmittingApplication: isSubmittingApplication,
            isDownloadingFile: isDownloadingFile,
            onCreateApplication: onCreateApplication,
            onOpenDocument: onOpenDocument,
            onEditApplication: onEditApplication,
            onDownloadApplicationForm: onDownloadApplicationForm
        )
    }
}

struct DormitoryAnnouncementCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let announcement: DormitoryAnnouncement
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(announcement.leadingMessage)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(announcement.requiredDocumentsIntro)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(announcement.requiredDocuments) { document in
                        BulletRow(document: document)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(announcement.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.secondary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
        .accessibilityAction(named: isExpanded ? "Свернуть" : "Развернуть") {
            AccessibilitySupport.update(reduceMotion: reduceMotion, animation: .snappy) {
                isExpanded.toggle()
            }
        }
    }
}

private struct BulletRow: View {
    let document: DormitoryAnnouncementDocument

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(.secondary)
            Text(documentText)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var documentText: AttributedString {
        var title = AttributedString(document.title)
        title.font = .callout.bold()

        guard let details = document.details else { return title }

        var result = title
        result.append(AttributedString(" (\(details))"))
        return result
    }
}

private struct PrivilegesSection: View {
    let records: [DormitoryPrivilegeRecord]
    @State private var isExpanded = false

    private var displayedRecords: [DormitoryPrivilegeRecord] {
        Dictionary(grouping: records, by: \.year)
            .compactMap { _, recordsForYear in
                recordsForYear.min {
                    if $0.displayPriority != $1.displayPriority {
                        return $0.displayPriority < $1.displayPriority
                    }
                    return $0.dormitoryPrivilegeCategoryName < $1.dormitoryPrivilegeCategoryName
                }
            }
            .sorted { $0.year > $1.year }
    }

    @ViewBuilder
    var body: some View {
        if let currentRecord = displayedRecords.first {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    ForEach(Array(displayedRecords.enumerated()), id: \.element.id) { index, record in
                        HStack(spacing: 12) {
                            Text(verbatim: String(record.year))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .leading)

                            Text(record.dormitoryPrivilegeCategoryName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)

                        if index < displayedRecords.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        NSLocalizedString("dormitory_section_privileges", comment: ""),
                        systemImage: "star.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.primary)

                    HStack(spacing: 5) {
                        Text(verbatim: String(currentRecord.year))
                            .monospacedDigit()
                        Text("·")
                        Text(currentRecord.dormitoryPrivilegeCategoryName)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
}

private extension DormitoryPrivilegeRecord {
    var displayPriority: Int {
        let normalized = dormitoryPrivilegeCategoryName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.contains("внеочеред") {
            return 0
        }
        if normalized.contains("первоочеред") {
            return 1
        }
        if normalized.contains("общ") {
            return 2
        }
        return 3
    }
}

private struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("error_data_load_failed", comment: ""), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(NSLocalizedString("common_retry", comment: ""), action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

let dormitoryDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("ddMMyyyy")
    return formatter
}()

#if DEBUG
extension DormitoryViewModel {
    static var previewVM: DormitoryViewModel {
        DormitoryViewModel.preview
    }
}

#Preview("Приоритетная льгота") {
    VStack {
        PrivilegesSection(
            records: [
                DormitoryPrivilegeRecord(
                    id: 1,
                    year: 2026,
                    dormitoryPrivilegeCategoryId: 6,
                    dormitoryPrivilegeCategoryName: "Общая очередь"
                ),
                DormitoryPrivilegeRecord(
                    id: 2,
                    year: 2026,
                    dormitoryPrivilegeCategoryId: 2,
                    dormitoryPrivilegeCategoryName: "Первоочередное право"
                ),
                DormitoryPrivilegeRecord(
                    id: 3,
                    year: 2025,
                    dormitoryPrivilegeCategoryId: 6,
                    dormitoryPrivilegeCategoryName: "Общая очередь"
                )
            ]
        )
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
