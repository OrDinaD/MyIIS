import Foundation

struct LibraryNewsEntry: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let link: URL
    let date: String
}

struct ScheduleEmployeeDirectoryEntry: Decodable, Identifiable, Hashable {
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let degree: String?
    let rank: String?
    let photoLink: String?
    let calendarId: String?
    let id: Int
    let urlId: String?
    let fio: String?

    var displayName: String {
        if let fio, !fio.isEmpty {
            return fio
        }
        let parts = [lastName, firstName, middleName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        if parts.isEmpty {
            return "ID \(id)"
        }
        return parts.joined(separator: " ")
    }
}

struct PublicScheduleResponse: Decodable {
    let employee: DisciplineEmployee?
    let group: StudyGroup?
    let exams: [DisciplineSchedule]
    let startDate: Date?
    let endDate: Date?
    let startExamsDate: Date?
    let endExamsDate: Date?
    private let scheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]
    private let previousScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]
    private let nextScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]

    enum CodingKeys: String, CodingKey {
        case employee = "employeeDto"
        case group = "studentGroupDto"
        case schedules
        case previousSchedules
        case nextSchedules
        case exams
        case startDate
        case endDate
        case startExamsDate
        case endExamsDate
    }

    static let publicationPending = PublicScheduleResponse(
        employee: nil,
        group: nil,
        exams: [],
        startDate: nil,
        endDate: nil,
        startExamsDate: nil,
        endExamsDate: nil,
        scheduleByWeekday: [:],
        previousScheduleByWeekday: [:],
        nextScheduleByWeekday: [:]
    )

    init(
        employee: DisciplineEmployee?,
        group: StudyGroup?,
        exams: [DisciplineSchedule],
        startDate: Date?,
        endDate: Date?,
        startExamsDate: Date?,
        endExamsDate: Date?,
        scheduleByWeekday: [StudyWeekday: [DisciplineSchedule]],
        previousScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]],
        nextScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]]
    ) {
        self.employee = employee
        self.group = group
        self.exams = exams
        self.startDate = startDate
        self.endDate = endDate
        self.startExamsDate = startExamsDate
        self.endExamsDate = endExamsDate
        self.scheduleByWeekday = scheduleByWeekday
        self.previousScheduleByWeekday = previousScheduleByWeekday
        self.nextScheduleByWeekday = nextScheduleByWeekday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateParser = StudyPlanDateParser.shared

        employee = try container.decodeIfPresent(DisciplineEmployee.self, forKey: .employee)
        group = try container.decodeIfPresent(StudyGroup.self, forKey: .group)

        let startDateRaw = try container.decodeIfPresent(String.self, forKey: .startDate)
        let endDateRaw = try container.decodeIfPresent(String.self, forKey: .endDate)
        let startExamsRaw = try container.decodeIfPresent(String.self, forKey: .startExamsDate)
        let endExamsRaw = try container.decodeIfPresent(String.self, forKey: .endExamsDate)
        startDate = dateParser.date(from: startDateRaw)
        endDate = dateParser.date(from: endDateRaw)
        startExamsDate = dateParser.date(from: startExamsRaw)
        endExamsDate = dateParser.date(from: endExamsRaw)

        exams = (try container.decodeIfPresent([DisciplineSchedule].self, forKey: .exams) ?? [])
            .sorted(by: DisciplineSchedule.sortingComparator)

        let rawSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .schedules) ?? [:]
        let rawPreviousSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .previousSchedules) ?? [:]
        let rawNextSchedules = try container.decodeIfPresent([String: [DisciplineSchedule]].self, forKey: .nextSchedules) ?? [:]

        scheduleByWeekday = Self.mapSchedule(rawSchedules)
        previousScheduleByWeekday = Self.mapSchedule(rawPreviousSchedules)
        nextScheduleByWeekday = Self.mapSchedule(rawNextSchedules)
    }

    var orderedDays: [StudyDaySchedule] {
        let source = actualScheduleByWeekday
        return StudyWeekday.displayOrder.compactMap { weekday in
            guard let lessons = source[weekday], !lessons.isEmpty else { return nil }
            return StudyDaySchedule(weekday: weekday, lessons: lessons)
        }
    }

    var availableWeekNumbers: [Int] {
        var result = Set<Int>()
        for day in orderedDays {
            for lesson in day.lessons {
                result.formUnion(lesson.weekNumbers)
            }
        }
        for exam in exams {
            result.formUnion(exam.weekNumbers)
        }
        return Array(result).sorted()
    }

    func isSchedulePublicationPending(referenceDate: Date = Date()) -> Bool {
        if scheduleByWeekday.isEmpty, nextScheduleByWeekday.isEmpty, exams.isEmpty {
            return true
        }

        guard !scheduleByWeekday.isEmpty, nextScheduleByWeekday.isEmpty, exams.isEmpty,
              let endDate else {
            return false
        }

        let calendar = Calendar.current
        let endExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: endDate)
        ) ?? endDate
        return referenceDate >= endExclusive
    }

    private var actualScheduleByWeekday: [StudyWeekday: [DisciplineSchedule]] {
        if !scheduleByWeekday.isEmpty {
            return scheduleByWeekday
        }
        if !nextScheduleByWeekday.isEmpty {
            return nextScheduleByWeekday
        }
        return [:]
    }

    private static func mapSchedule(_ rawValue: [String: [DisciplineSchedule]]) -> [StudyWeekday: [DisciplineSchedule]] {
        var mapped: [StudyWeekday: [DisciplineSchedule]] = [:]
        for (weekdayRaw, lessons) in rawValue {
            guard let weekday = StudyWeekday(rawValue: weekdayRaw) else { continue }
            mapped[weekday] = lessons.sorted(by: DisciplineSchedule.sortingComparator)
        }
        return mapped
    }
}

enum ServiceJSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: ServiceJSONValue])
    case array([ServiceJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ServiceJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([ServiceJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var scalarText: String? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null, .object, .array:
            return nil
        }
    }

    var shortText: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "Да" : "Нет"
        case .array(let values):
            return "Массив (\(values.count))"
        case .object(let object):
            return "Объект (\(object.count) полей)"
        case .null:
            return "—"
        }
    }
}

struct ServiceJSONObject: Codable, Hashable {
    let fields: [String: ServiceJSONValue]

    init(fields: [String: ServiceJSONValue]) {
        self.fields = fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.fields = try container.decode([String: ServiceJSONValue].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fields)
    }
}

struct ServiceJSONObjectPage: Decodable, Equatable {
    let content: [ServiceJSONObject]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let isLast: Bool
    let isEmpty: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case totalElements
        case totalPages
        case number
        case size
        case isLast = "last"
        case isEmpty = "empty"
    }
}

extension ServiceJSONObject {
    var stableID: String {
        if let id = fields["id"]?.scalarText {
            return id
        }
        if let title = fields["title"]?.scalarText {
            return title
        }
        let chunks = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.shortText)" }
        return chunks.joined(separator: "|")
    }

    var primaryText: String {
        if let value = fields["title"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["name"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["content"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["description"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["text"]?.scalarText, !value.isEmpty {
            return value
        }
        return stableID
    }

    var secondaryText: String? {
        if let value = fields["status"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["date"]?.scalarText, !value.isEmpty {
            return value
        }
        if let value = fields["createdDate"]?.scalarText, !value.isEmpty {
            return value
        }
        return nil
    }

    var detailPairs: [(String, String)] {
        fields
            .filter { !$0.key.hasPrefix("_") }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.shortText) }
    }
}

final class ServiceEndpointsAPI {
    private let baseURL: URL
    private let session: URLSession
    private let logService: LogService
    private let userDefaults = UserDefaults.standard

    private static let cachePrefix = "ServiceEndpointsAPI.cache."

    private struct CachedEnvelope: Codable {
        let data: Data
        let cachedAt: Date
    }

    init(
        baseURL: URL = URLFactory.require("https://iis.bsuir.by/api/v1"),
        session: URLSession = .shared,
        logService: LogService = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.logService = logService
    }

    func fetchLibraryBooks() async throws -> [ServiceJSONObject] {
        do {
            return try await decodeJSONArray(path: "library/books")
        } catch let APIError.serverError(statusCode, _) where statusCode == 404 {
            return []
        }
    }

    func fetchLibraryNews() async throws -> [LibraryNewsEntry] {
        do {
            let data = try await fetchData(path: "library/news")
            return try JSONDecoder().decode([LibraryNewsEntry].self, from: data)
        } catch let APIError.serverError(statusCode, _) where statusCode == 404 {
            return []
        }
    }

    func fetchAnnouncements() async throws -> [ServiceJSONObject] {
        let data = try await fetchData(path: "announcements/students")

        do {
            return try JSONDecoder().decode(ServiceJSONObjectPage.self, from: data).content
        } catch {
            if let legacyArray = try? JSONDecoder().decode([ServiceJSONObject].self, from: data) {
                return legacyArray
            }
            throw APIError.decodingError(error)
        }
    }

    func fetchPenalties() async throws -> [ServiceJSONObject] {
        try await decodeJSONArray(path: "dormitory-queue-application/premium-penalty")
    }

    func fetchIsBRSM() async throws -> Bool {
        try await decodeBool(path: "activity/is-brsm")
    }

    func fetchIsProfCom() async throws -> Bool {
        try await decodeBool(path: "activity/is-prof-com")
    }

    func fetchSocialWork() async throws -> [ServiceJSONObject] {
        try await decodeJSONArray(path: "activity/social-work")
    }

    func fetchResearchWork() async throws -> [ServiceJSONObject] {
        try await decodeJSONArray(path: "activity/research-work")
    }

    func fetchCurrentWeek() async throws -> Int {
        let data = try await fetchData(path: "schedule/current-week")
        do {
            return try JSONDecoder().decode(Int.self, from: data)
        } catch {
            if let asString = String(data: data, encoding: .utf8), let value = Int(asString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return value
            }
            throw APIError.decodingError(error)
        }
    }

    func fetchAllStudentGroups() async throws -> [StudyGroup] {
        let data = try await fetchData(path: "student-groups")
        do {
            return try JSONDecoder().decode([StudyGroup].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchAllEmployees() async throws -> [ScheduleEmployeeDirectoryEntry] {
        let data = try await fetchData(path: "employees/all")
        do {
            return try JSONDecoder().decode([ScheduleEmployeeDirectoryEntry].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchGroupSchedule(groupNumber: String) async throws -> PublicScheduleResponse {
        let data = try await fetchData(path: "schedule", queryItems: [
            URLQueryItem(name: "studentGroup", value: groupNumber)
        ])
        do {
            return try JSONDecoder().decode(PublicScheduleResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchEmployeeSchedule(urlId: String) async throws -> PublicScheduleResponse {
        let data = try await fetchData(path: "employees/schedule/\(urlId)")
        do {
            return try JSONDecoder().decode(PublicScheduleResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func cachedGroupSchedule(groupNumber: String) -> PublicScheduleResponse? {
        guard let request = try? makeGETRequest(path: "schedule", queryItems: [
            URLQueryItem(name: "studentGroup", value: groupNumber)
        ]), let data = cachedData(for: request) else {
            return nil
        }
        return try? JSONDecoder().decode(PublicScheduleResponse.self, from: data)
    }

    func cachedEmployeeSchedule(urlId: String) -> PublicScheduleResponse? {
        guard let request = try? makeGETRequest(path: "employees/schedule/\(urlId)"),
              let data = cachedData(for: request) else {
            return nil
        }
        return try? JSONDecoder().decode(PublicScheduleResponse.self, from: data)
    }

    func cachedStudentGroups() -> [StudyGroup]? {
        guard let request = try? makeGETRequest(path: "student-groups"),
              let data = cachedData(for: request) else {
            return nil
        }
        return try? JSONDecoder().decode([StudyGroup].self, from: data)
    }

    func cachedEmployees() -> [ScheduleEmployeeDirectoryEntry]? {
        guard let request = try? makeGETRequest(path: "employees/all"),
              let data = cachedData(for: request) else {
            return nil
        }
        return try? JSONDecoder().decode([ScheduleEmployeeDirectoryEntry].self, from: data)
    }

    func downloadGroupScheduleReport(groupNumber: String) async throws -> URL {
        let data = try await fetchData(path: "schedule/report", queryItems: [
            URLQueryItem(name: "student-group-name", value: groupNumber)
        ])
        let fileName = "Расписание \(Self.safeFileName(groupNumber)).xlsx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func decodeBool(path: String) async throws -> Bool {
        let data = try await fetchData(path: path)
        do {
            return try JSONDecoder().decode(Bool.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func decodeJSONArray(path: String) async throws -> [ServiceJSONObject] {
        let data = try await fetchData(path: path)

        if let objects = try? JSONDecoder().decode([ServiceJSONObject].self, from: data) {
            return objects
        }

        if let values = try? JSONDecoder().decode([ServiceJSONValue].self, from: data) {
            return values.enumerated().map { index, value in
                ServiceJSONObject(fields: [
                    "_index": .int(index),
                    "value": value
                ])
            }
        }

        throw APIError.decodingError(
            NSError(domain: "ServiceEndpointsAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported array payload"])
        )
    }

    private func fetchData(path: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        let request = try makeGETRequest(path: path, queryItems: queryItems)
        guard let endpoint = request.url else { throw APIError.invalidURL }

        let method = request.httpMethod ?? "GET"
        logService.log("Service endpoint request: \(method) \(endpoint.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = try validatedHTTPResponse(response)
            logService.log("Service endpoint response: status \(httpResponse.statusCode) for \(endpoint.absoluteString)")
            return try handleSuccessfulTransport(
                httpResponse: httpResponse,
                data: data,
                request: request
            )
        } catch {
            if isCancellationError(error) {
                throw CancellationError()
            }

            if let cached = cachedData(for: request) {
                logService.log("⚠️ Service endpoints: using offline cache for \(endpoint.absoluteString). Original error: \(error.localizedDescription)")
                return cached
            }

            if let apiError = error as? APIError {
                throw apiError
            }

            logTransportError(error, endpoint: endpoint)
            throw APIError.networkError(error)
        }
    }

    private func makeGETRequest(path: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        let endpoint = try endpointURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        return request
    }

    private func endpointURL(path: String, queryItems: [URLQueryItem]?) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let endpoint = components?.url else {
            throw APIError.invalidURL
        }
        return endpoint
    }

    private static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    private func validatedHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return httpResponse
    }

    private func handleSuccessfulTransport(
        httpResponse: HTTPURLResponse,
        data: Data,
        request: URLRequest
    ) throws -> Data {
        switch httpResponse.statusCode {
        case 200 ... 299:
            persistCache(data: data, for: request)
            return data
        case 401:
            throw APIError.unauthorized(message: "Сессия истекла. Войдите заново.")
        case 418:
            throw APIError.serviceUnavailable(message: "Сервис временно недоступен")
        default:
            let message = String(data: data, encoding: .utf8) ?? "Ошибка сервера"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func logTransportError(_ error: Error, endpoint: URL) {
        if let urlError = error as? URLError {
            logService.log("❌ Service endpoint transport error: \(urlError.code.rawValue) (\(urlError.code)) for \(endpoint.absoluteString)")
            if let failingURL = urlError.failingURL {
                logService.log("Failing URL: \(failingURL.absoluteString)")
            }
            return
        }

        let nsError = error as NSError
        logService.log("❌ Service endpoint transport NSError: \(nsError.domain) / \(nsError.code) for \(endpoint.absoluteString)")
    }

    private func persistCache(data: Data, for request: URLRequest) {
        guard let key = cacheKey(for: request) else { return }
        let envelope = CachedEnvelope(data: data, cachedAt: Date())
        guard let payload = try? JSONEncoder().encode(envelope) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: key, in: userDefaults)
    }

    private func cachedData(for request: URLRequest) -> Data? {
        guard let key = cacheKey(for: request),
              let payload = UserDefaultsPayloadStore.load(forKey: key, from: userDefaults),
              let envelope = try? JSONDecoder().decode(CachedEnvelope.self, from: payload) else {
            return nil
        }
        return envelope.data
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        let method = request.httpMethod?.uppercased() ?? "GET"
        return Self.cachePrefix + Data("\(method)|\(url)".utf8).base64EncodedString()
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return Task.isCancelled
    }
}
