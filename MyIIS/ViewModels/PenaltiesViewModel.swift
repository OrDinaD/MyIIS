import Foundation
import Combine
import SwiftUI

@MainActor
final class PenaltiesViewModel: ObservableObject {
    @Published private(set) var sections: [PenaltySection] = []
    @Published private(set) var status: ViewStatus = .idle
    @Published var selectedType: PenaltyType? {
        didSet { rebuildSections() }
    }

    var availableTypes: [PenaltyType] {
        let types = Set(allPenalties.map { $0.type })
        return PenaltyType.allCases
            .filter { $0 == .other ? types.contains(.other) : types.contains($0) }
            .sorted { lhs, rhs in
                if lhs.severityRank == rhs.severityRank {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.severityRank > rhs.severityRank
            }
    }

    private let service: PenaltiesServicing
    private var allPenalties: [PenaltyRecord] = []
    private var hasLoadedOnce = false

    init(service: PenaltiesServicing = PenaltiesService()) {
        self.service = service
    }

    func loadIfNeeded() async {
        if hasLoadedOnce { return }
        await load(force: true)
    }

    func reload() async {
        await load(force: true)
    }

    func selectType(_ type: PenaltyType?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedType = type
        }
    }

    private func load(force: Bool) async {
        if status == .loading && !force { return }
        if !force && hasLoadedOnce { return }

        status = .loading

        do {
            let penalties = try await service.fetchPenalties()
            apply(records: penalties)
        } catch let apiError as APIError {
            status = .failed(message: apiError.localizedDescription)
        } catch {
            status = .failed(message: "Не удалось загрузить взыскания")
        }
    }

    private func apply(records: [PenaltyRecord]) {
        hasLoadedOnce = true
        allPenalties = records.sorted(by: PenaltyRecord.defaultSort)
        rebuildSections()
    }

    private func rebuildSections() {
        let filtered = filteredPenalties()
        sections = PenaltiesViewModel.buildSections(from: filtered)

        if filtered.isEmpty {
            if allPenalties.isEmpty {
                status = hasLoadedOnce ? .empty : .idle
            } else if selectedType != nil {
                status = .filteredEmpty
            } else {
                status = .empty
            }
        } else {
            status = .loaded
        }
    }

    private func filteredPenalties() -> [PenaltyRecord] {
        guard let selectedType else { return allPenalties }
        return allPenalties.filter { $0.type == selectedType }
    }
}

extension PenaltiesViewModel {
    enum ViewStatus: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case filteredEmpty
        case failed(message: String)

        var title: String {
            switch self {
            case .idle:
                return "Взыскания"
            case .loading:
                return "Загрузка данных"
            case .loaded:
                return "Взыскания"
            case .empty:
                return "Нет взысканий"
            case .filteredEmpty:
                return "Нет взысканий выбранного типа"
            case .failed:
                return "Ошибка"
            }
        }

        var message: String? {
            switch self {
            case .idle:
                return ""
            case .loading:
                return "Обновляем историю дисциплинарных взысканий"
            case .loaded:
                return nil
            case .empty:
                return "Отличные новости! У вас нет дисциплинарных взысканий."
            case .filteredEmpty:
                return "В этом фильтре пока нет записей. Попробуйте выбрать другой тип."
            case .failed(let message):
                return message
            }
        }
    }

    struct PenaltySection: Identifiable, Equatable {
        let id: String
        let title: String
        let date: Date
        let items: [PenaltyRecord]
    }

    static func buildSections(from records: [PenaltyRecord], calendar: Calendar = .current) -> [PenaltySection] {
        guard !records.isEmpty else { return [] }

        let groups = Dictionary(grouping: records) { record -> Date in
            let components = calendar.dateComponents([.year, .month], from: record.issuedAt)
            return calendar.date(from: components) ?? record.issuedAt
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        return groups.map { date, items in
            PenaltySection(
                id: isoFormatter.string(from: date),
                title: formatter.string(from: date).capitalized,
                date: date,
                items: items.sorted(by: PenaltyRecord.defaultSort)
            )
        }
        .sorted { $0.date > $1.date }
    }
}

// MARK: - Previews

extension PenaltiesViewModel {
    static var preview: PenaltiesViewModel {
        let records: [PenaltyRecord] = [
            PenaltyRecord(
                recordID: UUID().uuidString,
                type: .severeReprimand,
                title: "Строгий выговор",
                description: "Нарушение общежитского режима",
                issuedAt: Date().addingTimeInterval(-86_400 * 10),
                updatedAt: nil,
                authority: "Комиссия по дисциплине",
                status: .active,
                note: "Необходимо явиться на беседу"
            ),
            PenaltyRecord(
                recordID: UUID().uuidString,
                type: .warning,
                title: "Предупреждение",
                description: "Опоздание на занятия",
                issuedAt: Date().addingTimeInterval(-86_400 * 42),
                updatedAt: nil,
                authority: "Деканат факультета",
                status: .resolved,
                note: nil
            ),
            PenaltyRecord(
                recordID: UUID().uuidString,
                type: .remark,
                title: "Замечание",
                description: "Отсутствие пропуска",
                issuedAt: Date().addingTimeInterval(-86_400 * 75),
                updatedAt: Date().addingTimeInterval(-86_400 * 60),
                authority: "Куратор",
                status: .cancelled,
                note: "Снято решением комиссии"
            )
        ]

        let mockService = PreviewPenaltiesService(records: records)
        let viewModel = PenaltiesViewModel(service: mockService)
        Task { await viewModel.loadIfNeeded() }
        return viewModel
    }
}

private final class PreviewPenaltiesService: PenaltiesServicing {
    private let records: [PenaltyRecord]

    init(records: [PenaltyRecord]) {
        self.records = records
    }

    func fetchPenalties() async throws -> [PenaltyRecord] {
        records
    }
}
