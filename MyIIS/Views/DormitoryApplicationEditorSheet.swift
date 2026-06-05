import SwiftUI
import UniformTypeIdentifiers

struct DormitoryApplicationEditorSheet: View {
    let context: DormitoryApplicationEditorContext
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onCreate: (URL?) -> Void
    let onUpdate: (DormitoryQueueApplication, DormitoryDocumentUpdateAction) -> Void

    @State private var isFileImporterPresented = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?
    @State private var removesExistingDocument = false
    @State private var fileErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Прикрепите документ, подтверждающий льготы")
                            .font(.headline)
                            .foregroundStyle(.blue)

                        Text(supportMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if hasExistingDocument {
                            Button(role: .destructive) {
                                selectedFileURL = nil
                                selectedFileName = nil
                                removesExistingDocument = true
                            } label: {
                                Label("Удалить файл", systemImage: "trash")
                            }
                        } else {
                            Button {
                                isFileImporterPresented = true
                            } label: {
                                Label(fileButtonTitle, systemImage: "paperclip")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Документ") {
                    Text(documentPreviewTitle)
                        .foregroundStyle(documentPreviewTint)
                }
            }
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", comment: ""), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(context.submitTitle)
                        }
                    }
                    .disabled(isSubmitDisabled)
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf, .jpeg, .png],
                allowsMultipleSelection: false
            ) { result in
                handleFileImporterResult(result)
            }
            .alert(NSLocalizedString("common_error", comment: ""), isPresented: Binding(
                get: { fileErrorMessage != nil },
                set: { if !$0 { fileErrorMessage = nil } }
            )) {
                Button(NSLocalizedString("common_ok", comment: ""), role: .cancel) {
                    fileErrorMessage = nil
                }
            } message: {
                Text(fileErrorMessage ?? "")
            }
        }
    }

    private var hasExistingDocument: Bool {
        context.application?.hasDocument == true && selectedFileURL == nil && !removesExistingDocument
    }

    private var supportMessage: String {
        hasExistingDocument
            ? "Заменить прикреплённый файл можно после нажатия на кнопку удаления."
            : "Принимаются документы в форматах PDF, JPEG, PNG."
    }

    private var fileButtonTitle: String {
        selectedFileName == nil ? "Выбрать файл" : "Заменить выбранный файл"
    }

    private var documentPreviewTitle: String {
        if let selectedFileName {
            return selectedFileName
        }
        if removesExistingDocument {
            return "Удалить текущий"
        }
        if let docReference = context.application?.docReference, !docReference.isEmpty {
            return "Без изменений"
        }
        return "Не прикреплён"
    }

    private var documentPreviewTint: Color {
        if removesExistingDocument { return .red }
        if selectedFileName != nil { return .primary }
        if context.application?.docReference != nil { return .blue }
        return .secondary
    }

    private var documentAction: DormitoryDocumentUpdateAction {
        if let selectedFileURL {
            return .replace(selectedFileURL)
        }
        if removesExistingDocument {
            return .remove
        }
        return .unchanged
    }

    private var isSubmitDisabled: Bool {
        if isSubmitting { return true }
        switch context {
        case .create:
            return false
        case .edit:
            return documentAction == .unchanged
        }
    }

    private func submit() {
        switch context {
        case .create:
            onCreate(selectedFileURL)
        case .edit(let application):
            onUpdate(application, documentAction)
        }
    }

    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let copiedURL = try copyImportedFile(url)
            selectedFileURL = copiedURL
            selectedFileName = copiedURL.lastPathComponent
            removesExistingDocument = false
        } catch {
            fileErrorMessage = error.localizedDescription
        }
    }

    private func copyImportedFile(_ url: URL) throws -> URL {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
}
