import Combine
import SwiftUI

@MainActor
final class LMSPageContentViewModel: ObservableObject {
    @Published var page: LMSPageContent?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let url: URL
    private let service = LMSActivityContentService.shared

    init(url: URL) {
        self.url = url
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            page = try await service.fetchPage(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LMSPageContentView: View {
    let url: URL
    let fallbackTitle: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LMSPageContentViewModel

    init(url: URL, fallbackTitle: String) {
        self.url = url
        self.fallbackTitle = fallbackTitle
        self._viewModel = StateObject(wrappedValue: LMSPageContentViewModel(url: url))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.page == nil {
                ProgressView("Загрузка страницы...")
            } else if let error = viewModel.errorMessage, viewModel.page == nil {
                ErrorStateView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if let page = viewModel.page {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HTMLTextBlock(html: page.contentHTML)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
            } else {
                ProgressView("Подготовка...")
            }
        }
        .navigationTitle(viewModel.page?.title ?? fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil && viewModel.page != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

@MainActor
final class LMSFeedbackViewModel: ObservableObject {
    @Published var page: LMSFeedbackPage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var values: [String: String] = [:]
    @Published var checkedOptionIDs: Set<String> = []

    private let url: URL
    private let service = LMSActivityContentService.shared

    init(url: URL) {
        self.url = url
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            apply(page: try await service.fetchFeedback(url: url))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit() async {
        guard let page, page.form != nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            apply(page: try await service.submitFeedback(page: page, values: values, checkedOptionIDs: checkedOptionIDs))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(page: LMSFeedbackPage) {
        self.page = page
        guard let form = page.form else { return }

        var nextValues = values
        var nextChecked = checkedOptionIDs
        for item in form.items {
            switch item.type {
            case .label:
                continue
            case .select, .singleChoice, .text, .textarea:
                guard let name = item.name, nextValues[name] == nil else { continue }
                nextValues[name] = item.defaultValue ?? form.fields[name] ?? ""
            case .multipleChoice:
                for option in item.options where option.isSelected {
                    nextChecked.insert(option.id)
                }
            }
        }
        values = nextValues
        checkedOptionIDs = nextChecked
    }
}

struct LMSFeedbackView: View {
    let url: URL
    let fallbackTitle: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LMSFeedbackViewModel
    @State private var confirmExit = false

    init(url: URL, fallbackTitle: String) {
        self.url = url
        self.fallbackTitle = fallbackTitle
        self._viewModel = StateObject(wrappedValue: LMSFeedbackViewModel(url: url))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.page == nil {
                ProgressView("Загрузка анкеты...")
            } else if let error = viewModel.errorMessage, viewModel.page == nil {
                ErrorStateView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if let page = viewModel.page {
                feedbackContent(page)
            } else {
                ProgressView("Подготовка...")
            }
        }
        .navigationTitle(viewModel.page?.title ?? fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") {
                    if viewModel.page?.form == nil {
                        dismiss()
                    } else {
                        confirmExit = true
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading && viewModel.page != nil {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil && viewModel.page != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Закрыть анкету?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Закрыть", role: .destructive) {
                dismiss()
            }
            Button("Остаться", role: .cancel) {}
        } message: {
            Text("Неотправленные ответы не сохранятся в СЭО.")
        }
    }

    @ViewBuilder
    private func feedbackContent(_ page: LMSFeedbackPage) -> some View {
        if let form = page.form {
            Form {
                ForEach(form.items) { item in
                    feedbackItemView(item)
                }

                Section {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        Text(form.submitValue)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
        } else {
            completionView(page.completionMessage ?? "Ответы отправлены.")
        }
    }

    @ViewBuilder
    private func feedbackItemView(_ item: LMSFeedbackItem) -> some View {
        switch item.type {
        case .label:
            Section {
                HTMLTextBlock(html: item.promptHTML)
                    .textSelection(.enabled)
            }
        case .select:
            Section {
                Picker(selection: valueBinding(for: item), label: promptLabel(item)) {
                    ForEach(item.options) { option in
                        Text(option.labelHTML.strippingSimpleHTML()).tag(option.value)
                    }
                }
            }
        case .singleChoice:
            Section {
                promptLabel(item)
                ForEach(item.options) { option in
                    Button {
                        if let name = item.name {
                            viewModel.values[name] = option.value
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: valueBinding(for: item).wrappedValue == option.value ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(Color.accentColor)
                                .padding(.top, 2)
                            HTMLTextBlock(html: option.labelHTML)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        case .multipleChoice:
            Section {
                promptLabel(item)
                ForEach(item.options) { option in
                    Toggle(isOn: checkedBinding(for: option.id)) {
                        HTMLTextBlock(html: option.labelHTML)
                    }
                }
            }
        case .text:
            Section {
                TextField(item.promptHTML.strippingSimpleHTML(), text: valueBinding(for: item), axis: .vertical)
                    .textInputAutocapitalization(.sentences)
            } header: {
                requiredHeader(item)
            }
        case .textarea:
            Section {
                TextEditor(text: valueBinding(for: item))
                    .frame(minHeight: 120)
            } header: {
                requiredHeader(item)
            }
        }
    }

    private func promptLabel(_ item: LMSFeedbackItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HTMLTextBlock(html: item.promptHTML)
            if item.isRequired {
                Text("Обязательное поле")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requiredHeader(_ item: LMSFeedbackItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.promptHTML.strippingSimpleHTML())
            if item.isRequired {
                Text("Обязательное поле")
                    .font(.caption2)
            }
        }
    }

    private func valueBinding(for item: LMSFeedbackItem) -> Binding<String> {
        Binding(
            get: {
                guard let name = item.name else { return "" }
                return viewModel.values[name] ?? item.defaultValue ?? ""
            },
            set: { newValue in
                guard let name = item.name else { return }
                viewModel.values[name] = newValue
            }
        )
    }

    private func checkedBinding(for optionID: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.checkedOptionIDs.contains(optionID) },
            set: { isOn in
                if isOn {
                    viewModel.checkedOptionIDs.insert(optionID)
                } else {
                    viewModel.checkedOptionIDs.remove(optionID)
                }
            }
        )
    }

    private func completionView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Анкета отправлена")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Закрыть") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }
}
