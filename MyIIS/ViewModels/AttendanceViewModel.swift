import Combine
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct AttendanceCacheModel: Codable {
    let applications: [OmissionApplication]
    let certificates: [OmissionCertificate]
    let monthlyCounts: [MonthlyOmissionCount]
    let faculty: String?
    let lastUpdateTime: Date
}

@Observable
@MainActor
final class AttendanceViewModel {
    enum Section: Hashable {
        case applications
        case summary
        case certificates
    }

    var applications: [OmissionApplication] = []
    var certificates: [OmissionCertificate] = [] {
        didSet {
            updateGroupedCertificates()
        }
    }
    private(set) var groupedCertificates: [(String, [OmissionCertificate])] = []
    var monthlyCounts: [MonthlyOmissionCount] = []
    var faculty: String?
    var isLoading: Bool = false
    var errorMessage: String?
    private(set) var sectionErrors: [Section: String] = [:]

    var lastUpdateTime: Date?
    var isShowingStaleDataWarning: Bool = false

    private let apiService: APIService
    private var hasLoadedOnce = false
    private static let cacheKey = "attendance_offline_cache"

    init() {
        self.apiService = APIService()
        self.loadCache()
    }

    init(apiService: APIService) {
        self.apiService = apiService
        self.loadCache()
    }

    private func loadCache() {
        guard let data = UserDefaultsPayloadStore.load(forKey: Self.cacheKey, from: .standard),
              let cache = try? JSONDecoder().decode(AttendanceCacheModel.self, from: data) else {
            return
        }
        self.applications = cache.applications
        self.certificates = cache.certificates
        self.monthlyCounts = cache.monthlyCounts
        self.faculty = cache.faculty
        self.lastUpdateTime = cache.lastUpdateTime
        self.updateGroupedCertificates()
    }

    private func updateGroupedCertificates() {
        let grouped = Dictionary(grouping: certificates) { $0.term }
        let sortedTerms = grouped.keys.sorted { (lhs, rhs) -> Bool in
            (Int(lhs) ?? 0) > (Int(rhs) ?? 0)
        }
        self.groupedCertificates = sortedTerms.map { term in
            (term, grouped[term, default: []].sorted { $0.dateFrom > $1.dateFrom })
        }
    }

    private func saveCache() {
        guard let lastUpdate = lastUpdateTime else { return }
        let cache = AttendanceCacheModel(
            applications: applications,
            certificates: certificates,
            monthlyCounts: monthlyCounts,
            faculty: faculty,
            lastUpdateTime: lastUpdate
        )
        if let data = try? JSONEncoder().encode(cache) {
            _ = UserDefaultsPayloadStore.save(data, forKey: Self.cacheKey, in: .standard)
        }
    }

    func loadDataIfNeeded() async { await loadData(force: false) }
    func reload() async { await loadData(force: true) }

    private func loadData(force: Bool) async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        sectionErrors = [:]

        async let applicationsTask: Result<[OmissionApplication], Error> = resultOf { try await apiService.getOmissionApplications() }
        async let countsTask: Result<[MonthlyOmissionCount], Error> = resultOf { try await apiService.getMonthlyOmissionCounts() }
        async let certificatesTask: Result<OmissionsByStudentResponse, Error> = resultOf { try await apiService.getOmissionsByStudent() }

        let applicationsResult = await applicationsTask
        let countsResult = await countsTask
        let certificatesResult = await certificatesTask

        if isCancellation(applicationsResult)
            || isCancellation(countsResult)
            || isCancellation(certificatesResult) {
            isLoading = false
            return
        }

        var errors: [String] = []
        var nextSectionErrors: [Section: String] = [:]
        var loadedSections = 0

        applyApplicationsResult(
            applicationsResult,
            errors: &errors,
            sectionErrors: &nextSectionErrors,
            loadedSections: &loadedSections
        )
        applyCountsResult(
            countsResult,
            errors: &errors,
            sectionErrors: &nextSectionErrors,
            loadedSections: &loadedSections
        )
        applyCertificatesResult(
            certificatesResult,
            errors: &errors,
            sectionErrors: &nextSectionErrors,
            loadedSections: &loadedSections
        )
        finalizeLoad(loadedSections: loadedSections, errors: errors, nextSectionErrors: nextSectionErrors)
        isLoading = false
    }

    private func finalizeLoad(loadedSections: Int, errors: [String], nextSectionErrors: [Section: String]) {
        if loadedSections > 0 {
            hasLoadedOnce = true
        }
        sectionErrors = nextSectionErrors

        if loadedSections == 3 {
            lastUpdateTime = Date()
            isShowingStaleDataWarning = false
            errorMessage = nil
            saveCache()
        } else if loadedSections > 0 {
            lastUpdateTime = Date()
            isShowingStaleDataWarning = false
            errorMessage = errors.first
            saveCache()
        } else if hasVisibleData {
            isShowingStaleDataWarning = true
            errorMessage = errors.first
        } else {
            errorMessage = errors.first ?? "Не удалось загрузить данные пропусков."
            isShowingStaleDataWarning = false
        }
    }

    private func applyApplicationsResult(
        _ result: Result<[OmissionApplication], Error>,
        errors: inout [String],
        sectionErrors: inout [Section: String],
        loadedSections: inout Int
    ) {
        switch result {
        case .success(let applications):
            self.applications = applications.sorted { $0.createdDate > $1.createdDate }
            loadedSections += 1
        case .failure(let error):
            if isNotFoundError(error) {
                self.applications = []
                loadedSections += 1
            } else {
                let message = resolveErrorMessage(error)
                errors.append(message)
                if self.applications.isEmpty {
                    sectionErrors[.applications] = message
                }
            }
        }
    }

    private func applyCountsResult(
        _ result: Result<[MonthlyOmissionCount], Error>,
        errors: inout [String],
        sectionErrors: inout [Section: String],
        loadedSections: inout Int
    ) {
        switch result {
        case .success(let counts):
            monthlyCounts = counts
            Self.persistWidgetSnapshot(with: counts)
            loadedSections += 1
        case .failure(let error):
            if isNotFoundError(error) {
                self.monthlyCounts = []
                loadedSections += 1
            } else {
                let message = resolveErrorMessage(error)
                errors.append(message)
                if monthlyCounts.isEmpty {
                    sectionErrors[.summary] = message
                }
            }
        }
    }

    private func applyCertificatesResult(
        _ result: Result<OmissionsByStudentResponse, Error>,
        errors: inout [String],
        sectionErrors: inout [Section: String],
        loadedSections: inout Int
    ) {
        switch result {
        case .success(let response):
            certificates = response.omissionDtoList.sorted { $0.dateFrom > $1.dateFrom }
            faculty = response.faculty
            loadedSections += 1
        case .failure(let error):
            if isNotFoundError(error) {
                self.certificates = []
                loadedSections += 1
            } else {
                let message = resolveErrorMessage(error)
                errors.append(message)
                if certificates.isEmpty {
                    sectionErrors[.certificates] = message
                }
            }
        }
    }

    private var hasVisibleData: Bool {
        !applications.isEmpty || !monthlyCounts.isEmpty || !certificates.isEmpty
    }

    private func resultOf<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func isCancellation<T>(_ result: Result<T, Error>) -> Bool {
        guard case .failure(let error) = result else { return false }
        return error is CancellationError
    }

    private func isNotFoundError(_ error: Error) -> Bool {
        if let apiError = error as? APIError, case .serverError(let statusCode, _) = apiError, statusCode == 404 {
            return true
        }
        return false
    }

    private func resolveErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return "Не удалось загрузить данные пропусков."
    }

    private static func persistWidgetSnapshot(with counts: [MonthlyOmissionCount]) {
        let total = counts.reduce(0) { $0 + $1.omissionCount }
        MyIISDataStore.update(unexcusedAbsences: total)

        guard let snapshot = makeSnapshot(from: counts) else { return }
        AttendanceWidgetDataStore.save(snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AttendanceWidgetConstants.kind)
#endif
    }

    private static func makeSnapshot(from counts: [MonthlyOmissionCount]) -> AttendanceWidgetSnapshot? {
        guard !counts.isEmpty else { return nil }
        guard let target = latestCount(in: counts) else { return nil }

        return AttendanceWidgetSnapshot(
            monthTitle: MonthParser.localizedTitle(from: target.month),
            unexcusedHours: target.omissionCount,
            updatedAt: Date()
        )
    }

    static func latestCount(in counts: [MonthlyOmissionCount]) -> MonthlyOmissionCount? {
        let resolved = resolvedCountsWithDates(counts, referenceDate: Date())

        if let latest = resolved.max(by: { $0.date < $1.date })?.item {
            return latest
        }

        // If month parsing fails, preserve backend order and pick the last available month.
        return counts.last
    }

    static func resolvedCountsWithDates(
        _ counts: [MonthlyOmissionCount],
        referenceDate: Date
    ) -> [(date: Date, item: MonthlyOmissionCount)] {
        counts.compactMap { item in
            guard let parsed = MonthParser.components(from: item.month),
                  let month = parsed.month
            else {
                return nil
            }

            let year = parsed.year ?? inferredYear(forMonth: month, referenceDate: referenceDate)

            var components = DateComponents()
            components.calendar = MonthParser.calendar
            components.year = year
            components.month = month
            components.day = 1

            guard let date = MonthParser.calendar.date(from: components) else {
                return nil
            }

            return (date, item)
        }
    }

    static func inferredYear(forMonth month: Int, referenceDate: Date) -> Int {
        let reference = MonthParser.calendar.dateComponents([.year, .month], from: referenceDate)
        let referenceYear = reference.year ?? MonthParser.calendar.component(.year, from: referenceDate)
        let referenceMonth = reference.month ?? MonthParser.calendar.component(.month, from: referenceDate)

        // If the month number is ahead of the current month, it likely belongs to the previous year.
        return month > referenceMonth ? referenceYear - 1 : referenceYear
    }
}

// MARK: - Month Parser

enum MonthParser {
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

        let symbols = formatter.monthSymbols + formatter.standaloneMonthSymbols + formatter.shortMonthSymbols
        var unique: [(value: String, index: Int)] = []

        for (index, symbol) in symbols.enumerated() {
            let monthIndex = (index % 12) + 1
            let normalized = normalize(symbol)
            guard !normalized.isEmpty else { continue }
            if unique.contains(where: { $0.value == normalized && $0.index == monthIndex }) {
                continue
            }
            unique.append((normalized, monthIndex))
        }

        return unique
    }()

    private static let numericMonthYearFormatters: [DateFormatter] = {
        ["MM.yyyy", "M.yyyy", "MM/yyyy", "M/yyyy", "yyyy-MM", "yyyy/MM", "yyyy.MM"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            return formatter
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

        for formatter in numericMonthYearFormatters {
            if let date = formatter.date(from: sanitized) {
                return calendar.dateComponents([.month, .year], from: date)
            }
        }

        let normalized = normalize(sanitized)
        if let match = normalizedMonthSymbols.first(where: { normalized.contains($0.value) }) {
            return DateComponents(month: match.index)
        }

        return nil
    }

    static func localizedTitle(
        from rawString: String,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let month = components(from: rawString)?.month,
              let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1))
        else {
            return rawString
        }

        let title = date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .locale(locale)
        )
        guard !title.isEmpty else { return rawString }

        return title.prefix(1).uppercased(with: locale) + String(title.dropFirst())
    }

    private static func sanitize(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: " г.", with: "")
            .replacingOccurrences(of: " г", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
