import SwiftUI

struct DormitoryApplicationEditorSheet: View {
    let context: DormitoryApplicationEditorContext
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onCreate: (URL?) -> Void
    let onOpenExistingDocument: (DormitoryQueueApplication) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(context.headerTitle, systemImage: context.headerSystemImage)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(context.supportMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                switch context {
                case .create:
                    createSection
                case .edit(let application):
                    documentSection(for: application)
                    websiteSection
                }
            }
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", comment: ""), action: onCancel)
                }
            }
        }
    }

    private var createSection: some View {
        Section {
            Button {
                onCreate(nil)
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(context.submitTitle)
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(isSubmitting)
        } footer: {
            Text("Если нужно приложить подтверждающий файл, выберите его на сайте iis.bsuir.by после подачи заявки.")
        }
    }

    private func documentSection(for application: DormitoryQueueApplication) -> some View {
        Section("Документ") {
            if application.hasDocument {
                Button {
                    onOpenExistingDocument(application)
                } label: {
                    Label("Просмотреть текущий файл", systemImage: "doc.text.magnifyingglass")
                }
            } else {
                Label("Файл не прикреплён", systemImage: "doc")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var websiteSection: some View {
        Section {
            Label {
                Text("Удалить вложение или выбрать новый файл можно в личном кабинете на сайте iis.bsuir.by.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "safari")
            }
        } header: {
            Text("На сайте")
        } footer: {
            Text("В приложении оставлен только просмотр текущего файла, чтобы не отправлять локальные документы через спорный сценарий.")
        }
    }
}

private extension DormitoryApplicationEditorContext {
    var headerTitle: String {
        switch self {
        case .create:
            return String(localized: "Заявка на общежитие")
        case .edit:
            return String(localized: "Вложение к заявке")
        }
    }

    var headerSystemImage: String {
        switch self {
        case .create:
            return "doc.badge.plus"
        case .edit:
            return "paperclip"
        }
    }

    var supportMessage: String {
        switch self {
        case .create:
            return String(localized: "Приложение отправит заявку без локального вложения. Подтверждающий файл лучше добавить через сайт.")
        case .edit:
            return String(localized: "Текущий файл можно открыть и сохранить. Удаление и замена вложения доступны на сайте.")
        }
    }
}
