import Foundation

@Observable
@MainActor
final class RatingOmissionsViewModel {
    private(set) var hours: Int?
    private(set) var isStale = false
    private(set) var updatedAt: Date?
    private var userID: Int?
    private let api: APIService
    private let defaults: UserDefaults

    private struct Snapshot: Codable {
        let counts: [MonthlyOmissionCount]
        let updatedAt: Date
    }

    init(api: APIService = APIService(), defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
    }

    func load(userID: Int, now: Date = Date()) async {
        guard userID > 0 else { return }
        if self.userID != userID {
            hours = nil
            updatedAt = nil
            self.userID = userID
        }
        let key = "rating_monthly_omissions.\(userID)"
        if let data = UserDefaultsPayloadStore.load(forKey: key, from: defaults),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            hours = Self.currentMonthHours(snapshot.counts, now: now)
            updatedAt = snapshot.updatedAt
        }
        do {
            let counts = try await api.getMonthlyOmissionCounts()
            try Task.checkCancellation()
            guard self.userID == userID else { return }
            hours = Self.currentMonthHours(counts, now: now)
            updatedAt = now
            isStale = false
            let snapshot = Snapshot(counts: counts, updatedAt: now)
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaultsPayloadStore.save(data, forKey: key, in: defaults)
            }
        } catch {
            guard self.userID == userID, !Task.isCancelled else { return }
            isStale = true
            if let error = error as? APIError, case .unauthorized = error {
                hours = nil
                updatedAt = nil
            }
        }
    }

    static func currentMonthHours(_ counts: [MonthlyOmissionCount], now: Date) -> Int? {
        let matching = AttendanceViewModel.resolvedCountsWithDates(counts, referenceDate: now)
            .filter { MonthParser.calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0) { $0 + $1.item.omissionCount }
    }
}
