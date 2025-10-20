import SwiftUI

@MainActor
struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel

    init(viewModel: LibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: LibraryViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 20) {
                    header
                    content
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Библиотека")
            .toolbar { toolbarContent }
            .task { await viewModel.loadIfNeeded() }
            .refreshable { await viewModel.refresh() }
            .animation(.easeInOut(duration: 0.25), value: viewModel.searchQuery)
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedSegment)
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            Picker("Раздел", selection: $viewModel.selectedSegment) {
                ForEach(LibraryViewModel.Segment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            .background(glassBackground(cornerRadius: 20))

            searchField
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Поиск по названию или автору", text: $viewModel.searchQuery, prompt: Text("Поиск по каталогу"))
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(glassBackground(cornerRadius: 22))
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                if let error = viewModel.errorMessage, !error.isEmpty {
                    ErrorCard(message: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    switch viewModel.selectedSegment {
                    case .active:
                        ActiveLoansSection(entries: viewModel.filteredActiveLoans)
                    case .archive:
                        ArchiveSection(entries: viewModel.filteredArchiveLoans)
                    case .catalog:
                        CatalogSection(items: viewModel.filteredCatalog)
                    }
                }

                if let placeholder = placeholderText, !placeholder.isEmpty {
                    PlaceholderCard(text: placeholder)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 60)
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView("Обновление данных...")
                    .progressViewStyle(.circular)
                    .padding(14)
                    .background(glassBackground(cornerRadius: 18))
                    .padding(.top, -10)
                    .padding(.bottom, 10)
            }
        }
    }

    private var placeholderText: String? {
        if let error = viewModel.errorMessage, !error.isEmpty {
            return nil
        }

        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        switch viewModel.selectedSegment {
        case .active:
            if viewModel.filteredActiveLoans.isEmpty {
                return query.isEmpty ? "Нет активных книг" : "Ничего не найдено"
            }
        case .archive:
            if viewModel.filteredArchiveLoans.isEmpty {
                return query.isEmpty ? "Архив пуст" : "Ничего не найдено"
            }
        case .catalog:
            if viewModel.filteredCatalog.isEmpty {
                return query.isEmpty ? "Каталог пока пуст" : "Ничего не найдено"
            }
        }

        return nil
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.05, blue: 0.15),
                Color(red: 0.16, green: 0.12, blue: 0.28),
                Color(red: 0.12, green: 0.18, blue: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func glassBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.purple.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private struct ActiveLoansSection: View {
    let entries: [BorrowHistoryEntry]

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            SectionHeader(title: "Активные книги", subtitle: "Ваши текущие выдачи")
            ForEach(entries) { entry in
                LibraryLoanCard(entry: entry)
            }
        }
    }
}

private struct ArchiveSection: View {
    let entries: [BorrowHistoryEntry]

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            SectionHeader(title: "Архив", subtitle: "Ранее возвращённые издания")
            ForEach(entries) { entry in
                LibraryLoanCard(entry: entry)
            }
        }
    }
}

private struct CatalogSection: View {
    let items: [LibraryItem]

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            SectionHeader(title: "Каталог", subtitle: "Доступные материалы библиотеки")
            ForEach(items) { item in
                LibraryCatalogCard(item: item)
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

private struct LibraryLoanCard: View {
    let entry: BorrowHistoryEntry

    private var statusColor: Color {
        switch entry.status {
        case .active: return Color.purple.opacity(0.7)
        case .overdue: return Color.red.opacity(0.8)
        case .returned: return Color.green.opacity(0.7)
        case .unknown: return Color.gray.opacity(0.6)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    if !entry.authors.isEmpty {
                        Text(entry.authorText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                StatusBadge(title: entry.status.title, color: statusColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let dueDate = entry.dueDate {
                    InfoRow(icon: entry.isOverdue ? "exclamationmark.triangle.fill" : "calendar") {
                        Text(entry.isOverdue ? "Просрочено до \(formatted(date: dueDate))" : "До \(formatted(date: dueDate))")
                    }
                }

                InfoRow(icon: "clock.arrow.circlepath") {
                    Text(entry.durationDescription)
                }

                if let location = entry.location, !location.isEmpty {
                    InfoRow(icon: entry.isElectronic ? "sparkles" : "building.columns") {
                        Text(location)
                    }
                }

                if entry.prolongationCount > 0 {
                    InfoRow(icon: "arrow.triangle.2.circlepath") {
                        Text("Продлений: \(entry.prolongationCount)")
                    }
                }
            }
        }
        .padding(22)
        .background(glassBackground)
        .overlay(glassBorder)
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), statusColor.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct LibraryCatalogCard: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                cover
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    if !item.authors.isEmpty {
                        Text(item.authorText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if let metadata = item.metadataText {
                        Text(metadata)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                if let availability = item.availability {
                    InfoChip(icon: "books.vertical.fill") {
                        Text("В наличии: \(availability.available) из \(availability.total)")
                    }
                }

                InfoChip(icon: "tag.fill") {
                    Text(item.itemTypeTitle)
                }
            }
        }
        .padding(22)
        .background(glassBackground)
        .overlay(glassBorder)
    }

    private var cover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.35), Color.blue.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 84)
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.purple.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

private struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(color.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.75), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct InfoRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            content()
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
    }
}

private struct InfoChip<Content: View>: View {
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            content()
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .foregroundStyle(.white.opacity(0.8))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct ErrorCard: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.85))
            Text("Не удалось загрузить данные")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(action: retryAction) {
                Label("Повторить", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct PlaceholderCard: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text(text)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private extension LibraryItem {
    var itemTypeTitle: String {
        switch itemType {
        case .book: return "Печатное издание"
        case .digital: return "Электронный ресурс"
        case .periodical: return "Периодика"
        case .dissertation: return "Диссертация"
        case .unknown: return "Материал"
        }
    }
}

#Preview {
    LibraryView(viewModel: .preview)
}
