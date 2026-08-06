import PassKit
import QuickLook
import SwiftUI

struct DormitoryView: View {
    @State private var viewModel: DormitoryViewModel
    @State private var previewURL: URL?
    @State private var editorContext: DormitoryApplicationEditorContext?
    @State private var passToPresent: PKPass?
    @State private var isShowingPassSheet = false
    @State private var walletNoticeMessage: String?
    @State private var isShowingWalletNotice = false

    @MainActor
    init(viewModel: DormitoryViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? DormitoryViewModel())
    }

    var body: some View {
        ZStack {
            ScrollView {
                dormitoryContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .allowsHitTesting(viewModel.settlementReveal == nil)

            if let reveal = viewModel.settlementReveal {
                DormitorySettlementRevealView(
                    reveal: reveal,
                    onDismiss: viewModel.completeSettlementReveal
                )
                .id(reveal.id)
                .transition(.opacity)
                .zIndex(20)
            }
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
        .animation(.snappy(duration: 0.32), value: viewModel.settlementReveal?.id)
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .onDisappear {
            viewModel.cancelSettlementReveal()
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
        .sheet(isPresented: $isShowingPassSheet) {
            if let pass = passToPresent {
                PKAddPassesViewControllerRepresentable(pass: pass) {
                    isShowingPassSheet = false
                }
            }
        }
        .alert("Добавление в Apple Wallet", isPresented: $isShowingWalletNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(walletNoticeMessage ?? "")
        }
    }

    @ViewBuilder
    private var dormitoryContent: some View {
        VStack(spacing: 16) {
            DormitoryPassCardView(
                passData: viewModel.currentPassData,
                onAddToWallet: {
                    Task {
                        await handleAddToWallet()
                    }
                }
            )

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
                },
                pendingSettlementApplicationID: viewModel.pendingSettlementApplicationID,
                onPresentSettlementReveal: viewModel.presentSettlementReveal
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

    private func handleAddToWallet() async {
        do {
            let pass = try await DormitoryWalletPassManager.shared.fetchWalletPass(for: viewModel.currentPassData)
            passToPresent = pass
            isShowingPassSheet = true
        } catch {
            walletNoticeMessage = error.localizedDescription
            isShowingWalletNotice = true
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
            return String(localized: "Оформление заявки на общежитие")
        case .edit:
            return String(localized: "Редактирование заявки на общежитие")
        }
    }

    var submitTitle: String {
        switch self {
        case .create:
            return String(localized: "Отправить заявку")
        case .edit:
            return String(localized: "Сохранить изменения")
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
    let pendingSettlementApplicationID: Int?
    let onPresentSettlementReveal: (DormitoryQueueApplication) -> Void

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
            onDownloadApplicationForm: onDownloadApplicationForm,
            pendingSettlementApplicationID: pendingSettlementApplicationID,
            onPresentSettlementReveal: onPresentSettlementReveal
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
        .accessibilityAction(
            named: Text(isExpanded ? String(localized: "Свернуть") : String(localized: "Развернуть"))
        ) {
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

    private var groups: [DormitoryPrivilegeYearGroup] {
        records.dormitoryPrivilegeYearGroups
    }

    @ViewBuilder
    var body: some View {
        if !groups.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups) { group in
                        DormitoryPrivilegeYearRow(group: group)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.secondary)

                    Text(NSLocalizedString("dormitory_section_privileges", comment: ""))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(records.count)")
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
}

private struct DormitoryPrivilegeYearRow: View {
    let group: DormitoryPrivilegeYearGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: String(group.year))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(group.records) { record in
                    DormitoryPrivilegeBadge(record: record)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private struct DormitoryPrivilegeBadge: View {
    let record: DormitoryPrivilegeRecord

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(record.dormitoryTint)
                .frame(width: 7, height: 7)

            Text(record.dormitoryPrivilegeCategoryName)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(record.dormitoryTint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            record.dormitoryTint.opacity(0.13),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

struct DormitoryPrivilegeYearGroup: Identifiable, Equatable {
    let year: Int
    let records: [DormitoryPrivilegeRecord]

    var id: Int { year }
}

extension Array where Element == DormitoryPrivilegeRecord {
    var dormitoryPrivilegeYearGroups: [DormitoryPrivilegeYearGroup] {
        Dictionary(grouping: self, by: \.year)
            .map { year, records in
                DormitoryPrivilegeYearGroup(
                    year: year,
                    records: records.sorted {
                        if $0.dormitoryDisplayPriority != $1.dormitoryDisplayPriority {
                            return $0.dormitoryDisplayPriority < $1.dormitoryDisplayPriority
                        }
                        return $0.dormitoryPrivilegeCategoryName < $1.dormitoryPrivilegeCategoryName
                    }
                )
            }
            .sorted { $0.year > $1.year }
    }
}

extension DormitoryPrivilegeRecord {
    var dormitoryDisplayPriority: Int {
        let normalized = dormitoryNormalizedCategory

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

    var dormitoryTint: Color {
        let normalized = dormitoryNormalizedCategory

        if normalized.contains("внеочеред") {
            return .pink
        }
        if normalized.contains("первоочеред") {
            return .purple
        }
        if normalized.contains("общ") {
            return .blue
        }
        if normalized.contains("обыч") {
            return .teal
        }
        return .orange
    }

    var dormitoryNormalizedCategory: String {
        dormitoryPrivilegeCategoryName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
                    year: 2026,
                    dormitoryPrivilegeCategoryId: 8,
                    dormitoryPrivilegeCategoryName: "Обычная очередь"
                ),
                DormitoryPrivilegeRecord(
                    id: 4,
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
