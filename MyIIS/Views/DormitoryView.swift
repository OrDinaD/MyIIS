import QuickLook
import SwiftUI

struct DormitoryView: View {
    @StateObject private var viewModel: DormitoryViewModel
    @State private var previewFileURL: URL?
    @State private var isLoadingDocument = false
    @State private var documentErrorMessage: String?
    private let documentService = DormitoryService()

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
        .alert(NSLocalizedString("dormitory_doc_unavailable", comment: ""), isPresented: Binding(
            get: { documentErrorMessage != nil },
            set: { if !$0 { documentErrorMessage = nil } }
        )) {
            Button(NSLocalizedString("common_ok", comment: ""), role: .cancel) { documentErrorMessage = nil }
        } message: {
            Text(documentErrorMessage ?? "")
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
                applications: viewModel.applications,
                isLoadingDocument: isLoadingDocument,
                onOpenDocument: { application in
                    Task {
                        await openDocument(for: application)
                    }
                }
            )
            PrivilegesSection(records: viewModel.privilegeRecords)
        }
    }

    private func openDocument(for application: DormitoryQueueApplication) async {
        if isLoadingDocument { return }
        isLoadingDocument = true
        defer { isLoadingDocument = false }

        do {
            let fileURL = try await documentService.downloadDocument(
                forRequestID: application.id,
                suggestedFileName: application.docReference
            )
            previewFileURL = fileURL
        } catch {
            if let localized = error as? LocalizedError, let message = localized.errorDescription {
                documentErrorMessage = message
            } else {
                documentErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct ApplicationsSection: View {
    let applications: [DormitoryQueueApplication]
    let isLoadingDocument: Bool
    let onOpenDocument: (DormitoryQueueApplication) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("dormitory_section_applications", comment: ""))
                .font(.headline)

            if applications.isEmpty {
                EmptyStateCard(text: NSLocalizedString("dormitory_no_applications", comment: ""))
            } else {
                ForEach(applications) { application in
                    ApplicationCard(
                        application: application,
                        isLoadingDocument: isLoadingDocument,
                        onOpenDocument: { onOpenDocument(application) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ApplicationCard: View {
    let application: DormitoryQueueApplication
    let isLoadingDocument: Bool
    let onOpenDocument: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                StatusTag(status: application.status)
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
                    ValueCaption(value: application.roomInfo ?? "—")
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
                        DocumentValueButton(
                            title: application.docReference ?? NSLocalizedString("dormitory_open_attachment", comment: ""),
                            isLoading: isLoadingDocument,
                            onOpen: onOpenDocument
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dormitoryDateFormatter.string(from: date)
    }
}

private struct DocumentValueButton: View {
    let title: String
    let isLoading: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onOpen) {
                Label(NSLocalizedString("dormitory_open_document", comment: ""), systemImage: "doc.text.viewfinder")
            }
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private struct PrivilegesSection: View {
    let records: [DormitoryPrivilegeRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("dormitory_section_privileges", comment: ""))
                .font(.headline)

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

private struct StatusTag: View {
    let status: String

    private var tint: Color {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("засел") {
            return .green
        }

        if normalized.contains("высел") {
            return .orange
        }

        if normalized.contains("отказ") {
            return .red
        }

        return .blue
    }

    var body: some View {
        Text(status)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
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
        DormitoryViewModel()
    }
}
#endif
