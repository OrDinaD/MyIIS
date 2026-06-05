import SwiftUI
import UniformTypeIdentifiers

struct DormitoryView: View {
    @StateObject private var viewModel: DormitoryViewModel
    @State private var previewFileURL: URL?
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
        .navigationTitle(NSLocalizedString("dormitory_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .sheet(isPresented: Binding(
            get: { previewFileURL != nil },
            set: { if !$0 { previewFileURL = nil } }
        )) {
            if let fileURL = previewFileURL {
                QuickLookPreview(url: fileURL)
            }
        }
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
                onUpdate: { application, action in
                    Task {
                        if await viewModel.updateApplication(application, documentAction: action) {
                            editorContext = nil
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
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
            if viewModel.isLoading && viewModel.applications.isEmpty && viewModel.privilegeRecords.isEmpty {
                ProgressView(NSLocalizedString("dormitory_loading", comment: ""))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
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
            previewFileURL = fileURL
        }
    }

    private func downloadApplicationForm(for application: DormitoryQueueApplication) async {
        if let fileURL = await viewModel.downloadApplicationForm(for: application) {
            previewFileURL = fileURL
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
        VStack(alignment: .leading, spacing: 12) {
            if let announcement {
                DormitoryAnnouncementCard(announcement: announcement)
            }

            DormitorySectionHeader(
                title: NSLocalizedString("dormitory_section_applications", comment: ""),
                systemImage: "building.2"
            )

            Button(action: onCreateApplication) {
                Label("Подать заявку", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canCreateApplication || isSubmittingApplication)
            .accessibilityHint(canCreateApplication ? "Открывает форму подачи заявки" : "Подача заявки сейчас недоступна")

            if applications.isEmpty {
                EmptyStateCard(text: NSLocalizedString("dormitory_no_applications", comment: ""))
            } else {
                ForEach(applications) { application in
                    ApplicationCard(
                        application: application,
                        isDownloadingFile: isDownloadingFile,
                        onOpenDocument: { onOpenDocument(application) },
                        onEditApplication: { onEditApplication(application) },
                        onDownloadApplicationForm: { onDownloadApplicationForm(application) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DormitoryAnnouncementCard: View {
    let announcement: DormitoryAnnouncement
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(announcement.leadingMessage)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(announcement.requiredDocumentsIntro)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(announcement.requiredDocuments) { document in
                        BulletRow(document: document)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            Label(announcement.title, systemImage: "megaphone.fill")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(.blue)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 1.0, green: 0.90, blue: 0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.blue.opacity(0.35), lineWidth: 1)
        )
        .accessibilityAction(named: isExpanded ? "Свернуть" : "Развернуть") {
            withAnimation(.snappy) {
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
                .foregroundStyle(.primary)
            Text(documentText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var documentText: AttributedString {
        var title = AttributedString(document.title)
        title.font = .subheadline.bold()

        guard let details = document.details else { return title }

        var result = title
        result.append(AttributedString(" (\(details))"))
        return result
    }
}

private struct ApplicationCard: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void
    let onDownloadApplicationForm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: NSLocalizedString("dormitory_application_number", comment: ""), application.number))
                        .font(.subheadline.weight(.semibold))
                    if let acceptedDate = application.acceptedDate {
                        Text(String(format: NSLocalizedString("dormitory_application_accepted", comment: ""), dormitoryDateFormatter.string(from: acceptedDate)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                DormitoryStatusTag(status: application.status)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    LabelCaption(title: NSLocalizedString("dormitory_label_app_date", comment: ""))
                    ValueCaption(value: formattedDate(application.applicationDate))
                }

                GridRow {
                    LabelCaption(title: NSLocalizedString("dormitory_label_settle_date", comment: ""))
                    ValueCaption(value: formattedDate(application.settledDate))
                }

                GridRow {
                    LabelCaption(title: NSLocalizedString("dormitory_label_room", comment: ""))
                    ValueCaption(value: application.roomInfo ?? "-")
                }

                if let queueNumber = application.numberInQueue {
                    GridRow {
                        LabelCaption(title: NSLocalizedString("dormitory_label_queue_number", comment: ""))
                        ValueCaption(value: String(queueNumber))
                    }
                }

                if let reason = application.rejectionReason, !reason.isEmpty {
                    GridRow {
                        LabelCaption(title: NSLocalizedString("dormitory_label_reason", comment: ""))
                        ValueCaption(value: reason)
                    }
                }

                if application.hasDocument {
                    GridRow {
                        LabelCaption(title: NSLocalizedString("dormitory_label_document", comment: ""))
                        ValueCaption(value: application.docReference ?? NSLocalizedString("dormitory_open_attachment", comment: ""))
                    }
                }
            }

            ApplicationActions(
                application: application,
                isDownloadingFile: isDownloadingFile,
                onOpenDocument: onOpenDocument,
                onEditApplication: onEditApplication,
                onDownloadApplicationForm: onDownloadApplicationForm
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if application.hasDocument {
                Button("Скачать прикреплённый файл", action: onOpenDocument)
            }
            if application.canEdit {
                Button("Редактировать заявку", action: onEditApplication)
            }
            if application.canDownloadApplicationForm {
                Button("Скачать заявление", action: onDownloadApplicationForm)
            }
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return dormitoryDateFormatter.string(from: date)
    }
}

private struct ApplicationActions: View {
    let application: DormitoryQueueApplication
    let isDownloadingFile: Bool
    let onOpenDocument: () -> Void
    let onEditApplication: () -> Void
    let onDownloadApplicationForm: () -> Void

    var body: some View {
        let hasActions = application.hasDocument || application.canEdit || application.canDownloadApplicationForm
        if hasActions {
            VStack(alignment: .leading, spacing: 8) {
                Text("Действия")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if application.hasDocument {
                        ApplicationActionButton(
                            title: "Скачать прикреплённый файл",
                            systemImage: "paperclip",
                            isDisabled: isDownloadingFile,
                            action: onOpenDocument
                        )
                    }

                    if application.canEdit {
                        ApplicationActionButton(
                            title: "Редактировать заявку",
                            systemImage: "square.and.pencil",
                            isDisabled: false,
                            action: onEditApplication
                        )
                    }

                    if application.canDownloadApplicationForm {
                        ApplicationActionButton(
                            title: "Скачать заявление",
                            systemImage: "arrow.down.doc",
                            isDisabled: isDownloadingFile,
                            action: onDownloadApplicationForm
                        )
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct ApplicationActionButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 42, height: 36)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

private struct PrivilegesSection: View {
    let records: [DormitoryPrivilegeRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DormitorySectionHeader(
                title: NSLocalizedString("dormitory_section_privileges", comment: ""),
                systemImage: "star.circle"
            )

            if records.isEmpty {
                EmptyStateCard(text: NSLocalizedString("dormitory_no_privileges", comment: ""))
            } else {
                ForEach(records) { record in
                    HStack(spacing: 12) {
                        Text(String(record.year))
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 56, alignment: .leading)

                        Text(record.dormitoryPrivilegeCategoryName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DormitorySectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct LabelCaption: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ValueCaption: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

private struct EmptyStateCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

private let dormitoryDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter
}()

#if DEBUG
extension DormitoryViewModel {
    static var previewVM: DormitoryViewModel {
        DormitoryViewModel.preview
    }
}
#endif
