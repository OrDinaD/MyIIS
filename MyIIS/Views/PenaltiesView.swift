import SwiftUI

@MainActor
struct PenaltiesView: View {
    @StateObject private var viewModel: PenaltiesViewModel

    init(viewModel: PenaltiesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: PenaltiesViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                content
            }
            .navigationTitle("Взыскания")
            .toolbar { toolbarContent }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loading:
            loadingState
        case .failed(let message):
            errorState(message: message)
        case .empty:
            emptyState(title: "Нет взысканий", message: viewModel.status.message)
        case .filteredEmpty:
            emptyState(title: "Нет записей", message: viewModel.status.message)
        case .loaded:
            penaltiesList
        }
    }

    private var penaltiesList: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !viewModel.availableTypes.isEmpty {
                    filterChips
                }

                ForEach(viewModel.sections) { section in
                    sectionView(section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private var loadingState: some View {
        let message = viewModel.status.message
        return VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.purple)
            Text((message?.isEmpty == false ? message! : "Обновляем историю дисциплинарных взысканий"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, options: .repeat(3))

            Text("Не удалось загрузить взыскания")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(title: String, message: String?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .symbolEffect(.pulse)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterChip(title: "Все", type: nil, systemImage: "line.3.horizontal.decrease.circle")

                ForEach(viewModel.availableTypes) { type in
                    filterChip(title: type.displayName, type: type, systemImage: type.systemImageName)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func filterChip(title: String, type: PenaltyType?, systemImage: String) -> some View {
        let isSelected = viewModel.selectedType == type

        return Button {
            viewModel.selectType(isSelected ? nil : type)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: isSelected ? chipColors(for: type) : [.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.thinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func sectionView(_ section: PenaltiesViewModel.PenaltySection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 12)

            VStack(spacing: 20) {
                ForEach(Array(section.items.enumerated()), id: \.1.id) { index, record in
                    timelineRow(for: record, isLast: index == section.items.count - 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func timelineRow(for record: PenaltyRecord, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            timelineIndicator(isLast: isLast, type: record.type)
            penaltyCard(for: record)
        }
    }

    private func timelineIndicator(isLast: Bool, type: PenaltyType) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(chipColors(for: type).first ?? .purple)
                .frame(width: 12, height: 12)
                .shadow(color: (chipColors(for: type).first ?? .purple).opacity(0.6), radius: 4)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 20)
    }

    private func penaltyCard(for record: PenaltyRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: record.type.systemImageName)
                    .font(.title3)
                    .foregroundStyle(chipColors(for: record.type).first ?? .purple)
                    .symbolRenderingMode(.palette)

                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title)
                        .font(.headline)
                    Text(dateFormatter.string(from: record.issuedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(record.displayDescription)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.9))

            if let authority = record.authority {
                Label(authority, systemImage: "person.fill.badge.checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            statusBadge(for: record.status)

            if record.status.isCritical {
                criticalNotice
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(chipColors(for: record.type).first?.opacity(0.4) ?? .purple.opacity(0.4), lineWidth: 1)
        )
    }

    private func statusBadge(for status: PenaltyRecord.Status) -> some View {
        Label(status.displayName, systemImage: status.symbolName)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusBackground(for: status), in: Capsule())
            .foregroundStyle(statusForeground(for: status))
    }

    private var criticalNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
            Text("Требуются действия: свяжитесь с деканатом.")
        }
        .font(.footnote)
        .padding(10)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(Color.red)
    }

    private func chipColors(for type: PenaltyType?) -> [Color] {
        guard let type else { return [.purple.opacity(0.65), .blue.opacity(0.65)] }
        switch type {
        case .remark:
            return [Color.cyan.opacity(0.7), Color.blue.opacity(0.6)]
        case .warning:
            return [Color.orange.opacity(0.7), Color.yellow.opacity(0.6)]
        case .reprimand:
            return [Color.pink.opacity(0.7), Color.red.opacity(0.6)]
        case .severeReprimand:
            return [Color.red, Color.purple.opacity(0.8)]
        case .dismissal:
            return [Color.black.opacity(0.8), Color.red.opacity(0.8)]
        case .other:
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }
    }

    private func statusBackground(for status: PenaltyRecord.Status) -> LinearGradient {
        switch status {
        case .active:
            return LinearGradient(colors: [Color.red.opacity(0.25), Color.orange.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .resolved:
            return LinearGradient(colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cancelled:
            return LinearGradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .expired:
            return LinearGradient(colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unknown:
            return LinearGradient(colors: [Color.gray.opacity(0.2), Color.blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func statusForeground(for status: PenaltyRecord.Status) -> Color {
        switch status {
        case .active:
            return .red
        case .resolved:
            return .green
        case .cancelled:
            return .gray
        case .expired:
            return .orange
        case .unknown:
            return .blue
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }

                if !viewModel.availableTypes.isEmpty {
                    Divider()
                    Button {
                        viewModel.selectType(nil)
                    } label: {
                        Label("Сбросить фильтр", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground).opacity(0.95),
                Color(uiColor: .secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        return formatter
    }
}

#Preview {
    PenaltiesView(viewModel: .preview)
}
