import SwiftUI

@MainActor
struct DiplomaServiceView: View {
    @StateObject private var viewModel = DiplomaApplicationViewModel()
    @State private var isRequestFormPresented = false
    @State private var applicationToDelete: DiplomaApplication?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.staleErrorMessage) {
                        await viewModel.reload()
                    }
                }

                DiplomaStatusCard(
                    title: viewModel.screenTitle,
                    message: viewModel.statusMessage,
                    canOpenForm: viewModel.canOpenRequestForm,
                    isLoading: viewModel.isLoading || viewModel.isSubmitting
                ) {
                    isRequestFormPresented = true
                }

                if let url = viewModel.downloadedApplicationURL {
                    DownloadedApplicationCard(url: url) {
                        viewModel.clearDownloadedApplication()
                    }
                }

                if viewModel.applications.isEmpty {
                    DiplomaEmptyApplicationsView()
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.applications) { application in
                            DiplomaApplicationCard(
                                application: application,
                                isDownloading: viewModel.isDownloading,
                                onDownload: {
                                    Task {
                                        await viewModel.downloadApplication(application)
                                    }
                                },
                                onDelete: {
                                    applicationToDelete = application
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Диплом")
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .overlay {
            if viewModel.isLoading && viewModel.applications.isEmpty {
                ProgressView("Загрузка...")
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .sheet(isPresented: $isRequestFormPresented) {
            DiplomaRequestFormView(viewModel: viewModel)
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.errorMessage = nil
                }
            }
        ), actions: {
            Button("ОК") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .alert("Готово", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.successMessage = nil
                }
            }
        ), actions: {
            Button("ОК") { viewModel.successMessage = nil }
        }, message: {
            Text(viewModel.successMessage ?? "")
        })
        .confirmationDialog(
            "Отменить заявку?",
            isPresented: Binding(
                get: { applicationToDelete != nil },
                set: { shouldShow in
                    if !shouldShow {
                        applicationToDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Отменить заявку", role: .destructive) {
                guard let applicationToDelete else { return }
                Task {
                    await viewModel.deleteApplication(applicationToDelete)
                    self.applicationToDelete = nil
                }
            }
            Button("Закрыть", role: .cancel) {
                applicationToDelete = nil
            }
        } message: {
            Text("Заявка будет удалена в ИИС.")
        }
    }
}
private struct DiplomaStatusCard: View {
    let title: String
    let message: String
    let canOpenForm: Bool
    let isLoading: Bool
    let onOpenForm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 38, height: 38)
                    .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            Button {
                onOpenForm()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                    }
                    Text("Оформить заявку")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canOpenForm)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DiplomaApplicationCard: View {
    let application: DiplomaApplication
    let isDownloading: Bool
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(application.topic)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(application.supervisorName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(application.status)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .foregroundStyle(statusColor)
                    .background(statusColor.opacity(0.14), in: Capsule())
            }

            VStack(spacing: 8) {
                InfoLine(title: "Дата подачи", value: application.date ?? "Не указана")
                if let belarusianTopic = application.belarusianTopic, !belarusianTopic.isEmpty {
                    InfoLine(title: "Тема на бел.", value: belarusianTopic)
                }
                if let englishTopic = application.englishTopic, !englishTopic.isEmpty {
                    InfoLine(title: "Тема на англ.", value: englishTopic)
                }
                if let justification = application.justification, !justification.isEmpty {
                    InfoLine(title: "Обоснование", value: justification)
                }
                if let rejectionReason = application.rejectionReason, !rejectionReason.isEmpty {
                    InfoLine(title: "Причина отказа", value: rejectionReason)
                }
            }

            if application.canDownloadApplication || application.canCancel {
                HStack(spacing: 10) {
                    if application.canDownloadApplication {
                        Button {
                            onDownload()
                        } label: {
                            Label(isDownloading ? "Формируем..." : "Скачать заявление", systemImage: "doc.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isDownloading)
                    }

                    if application.canCancel {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Отменить", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusColor: Color {
        switch application.statusId {
        case 1, 2:
            return .green
        case 5:
            return .orange
        case 3, 4:
            return .red
        default:
            return .blue
        }
    }
}

private struct DownloadedApplicationCard: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text("Заявление сформировано")
                    .font(.subheadline.weight(.semibold))
                ShareLink(item: url) {
                    Text("Открыть или отправить файл")
                        .font(.caption)
                }
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DiplomaEmptyApplicationsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Заявок пока нет")
                .font(.headline)
            Text("После отправки заявки она появится здесь со статусом рассмотрения.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DiplomaRequestFormView: View {
    @ObservedObject var viewModel: DiplomaApplicationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    supervisorSection
                    topicSection
                    submitButton
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Оформить заявку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task(id: viewModel.supervisorQuery) {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await viewModel.searchSupervisors()
            }
        }
    }

    private var supervisorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Руководитель", required: true)

            TextField("Введите ФИО руководителя", text: $viewModel.supervisorQuery)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let selectedSupervisor = viewModel.selectedSupervisor {
                SelectedSupervisorView(supervisor: selectedSupervisor)
            }

            if viewModel.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Ищем руководителей...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if !viewModel.supervisors.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.supervisors) { supervisor in
                        Button {
                            Task {
                                await viewModel.selectSupervisor(supervisor)
                            }
                        } label: {
                            SupervisorResultRow(supervisor: supervisor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.selectedSupervisor?.employeeId != nil {
                SectionTitle(title: "Темы, предложенные руководителем", required: false)

                if viewModel.employeeTopics.isEmpty {
                    Text("У выбранного руководителя нет предложенных тем.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.employeeTopics) { topic in
                            Button {
                                viewModel.selectTopic(topic)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: viewModel.selectedTopic?.id == topic.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.selectedTopic?.id == topic.id ? .blue : .secondary)
                                    Text(topic.topic)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            let topicSectionTitle = viewModel.selectedSupervisor?.employeeId == nil
                ? "Введите тему диплома"
                : "Или введите свою тему"
            SectionTitle(title: topicSectionTitle, required: viewModel.selectedTopic == nil)

            TextField("Введите тему", text: $viewModel.topicName)
                .disabled(viewModel.selectedTopic != nil)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: viewModel.topicName) { _, newValue in
                    if !newValue.isEmpty {
                        viewModel.selectTopic(nil)
                    }
                }

            TextField(viewModel.localizedTopicPlaceholder, text: $viewModel.localizedTopicName)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                let needsJustification = viewModel.selectedTopic == nil
                    && !viewModel.topicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                SectionTitle(title: "Обоснование темы", required: needsJustification)
                TextEditor(text: $viewModel.justification)
                    .frame(minHeight: 96)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var submitButton: some View {
        Button {
            Task {
                let didSubmit = await viewModel.submitApplication()
                if didSubmit {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSubmitting {
                    ProgressView()
                }
                Text("Отправить заявку")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSubmitApplication)
    }
}
