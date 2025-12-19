import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class AttendanceViewModel: ObservableObject {
    @Published var applications: [OmissionApplication] = []
    @Published var certificates: [OmissionCertificate] = []
    @Published var monthlyCounts: [MonthlyOmissionCount] = []
    @Published var faculty: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiService: APIService
    private var hasLoadedOnce = false

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func loadDataIfNeeded() async { await loadData(force: false) }
    func reload() async { await loadData(force: true) }

    private func loadData(force: Bool) async {
        if isLoading { return }
        if hasLoadedOnce && !force { return }

        isLoading = true
        errorMessage = nil

        do {
            async let applicationsTask = apiService.getOmissionApplications()
            async let countsTask = apiService.getMonthlyOmissionCounts()
            async let certificatesTask = apiService.getOmissionsByStudent()

            let (applications, counts, certificatesResponse) = try await (
                applicationsTask, countsTask, certificatesTask
            )

            self.applications = applications.sorted { $0.createdDate > $1.createdDate }
            self.monthlyCounts = counts
            self.certificates = certificatesResponse.omissionDtoList.sorted { $0.dateFrom > $1.dateFrom }
            self.faculty = certificatesResponse.faculty
            Self.persistWidgetSnapshot(with: counts)
            hasLoadedOnce = true
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = "Не удалось загрузить данные пропусков."
        }

        isLoading = false
    }

    private static func persistWidgetSnapshot(with counts: [MonthlyOmissionCount]) {
        guard let snapshot = makeSnapshot(from: counts) else { return }
        AttendanceWidgetDataStore.save(snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AttendanceWidgetConstants.kind)
#endif
    }

    private static func makeSnapshot(from counts: [MonthlyOmissionCount]) -> AttendanceWidgetSnapshot? {
        guard !counts.isEmpty else { return nil }
        let target = currentMonthCount(in: counts) ?? mostRecentCount(in: counts)
        guard let target else { return nil }

        return AttendanceWidgetSnapshot(
            monthTitle: target.month,
            unexcusedHours: target.omissionCount,
            updatedAt: Date()
        )
    }

    private static func currentMonthCount(in counts: [MonthlyOmissionCount]) -> MonthlyOmissionCount? {
        let now = Date()
        let components = MonthParser.calendar.dateComponents([.month, .year], from: now)

        return counts.first { item in
            guard let parsed = MonthParser.components(from: item.month),
                  let month = parsed.month,
                  let currentMonth = components.month
            else { return false }

            guard month == currentMonth else { return false }

            if let itemYear = parsed.year, let currentYear = components.year {
                return itemYear == currentYear
            }
            return true
        }
    }

    private static func mostRecentCount(in counts: [MonthlyOmissionCount]) -> MonthlyOmissionCount? {
        let referenceYear = MonthParser.calendar.component(.year, from: Date())

        let resolved = counts.compactMap { item -> (date: Date, item: MonthlyOmissionCount)? in
            guard let parsed = MonthParser.components(from: item.month),
                  let month = parsed.month
            else { return nil }

            var components = DateComponents()
            components.calendar = MonthParser.calendar
            components.month = month
            components.year = parsed.year ?? referenceYear

            guard let date = MonthParser.calendar.date(from: components) else { return nil }
            return (date, item)
        }

        if let latest = resolved.sorted(by: { $0.date > $1.date }).first?.item {
            return latest
        }

        return counts.last
    }
}

// MARK: - Month Parser

private enum MonthParser {
    static let locale = Locale(identifier: "ru_RU")
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter
    }()

    private static let normalizedMonthSymbols: [(value: String, index: Int)] = {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.monthSymbols.enumerated().map { index, symbol in
            (normalize(symbol), index + 1)
        }
    }()

    static func components(from rawString: String) -> DateComponents? {
        let sanitized = sanitize(rawString)
        let containsDigits = sanitized.rangeOfCharacter(from: .decimalDigits) != nil

        if let date = monthYearFormatter.date(from: sanitized) {
            var components = calendar.dateComponents([.month, .year], from: date)
            if !containsDigits {
                components.year = nil
            }
            return components
        }

        if let date = monthFormatter.date(from: sanitized) {
            var components = calendar.dateComponents([.month, .year], from: date)
            if !containsDigits {
                components.year = nil
            }
            return components
        }

        let normalized = normalize(sanitized)
        if let match = normalizedMonthSymbols.first(where: { normalized.contains($0.value) }) {
            return DateComponents(month: match.index)
        }

        return nil
    }

    private static func sanitize(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return collapsed
    }

    private static func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
