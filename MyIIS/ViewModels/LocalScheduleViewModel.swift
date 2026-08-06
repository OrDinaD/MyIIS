import Combine
import Foundation
import Observation

@MainActor
@Observable
final class LocalScheduleViewModel {
    private(set) var document: LocalScheduleDocument?
    var errorMessage: String?
    var noticeMessage: String?

    private let defaults: UserDefaults
    private static let installedFixtureDefaultsKey = "local.schedule.fixture.2026-07-28"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    var groupedEvents: [(date: String, events: [LocalScheduleDocument.Event])] {
        let grouped = Dictionary(grouping: document?.sortedEvents ?? [], by: \.date)
        return grouped.keys.sorted().map { date in
            (date, grouped[date] ?? [])
        }
    }

    var currentFileURL: URL? {
        LocalScheduleStore.currentFileURL()
    }

    func reload() {
        do {
            if !defaults.bool(forKey: Self.installedFixtureDefaultsKey),
               let bundledExample = try LocalScheduleStore.loadBundledExample() {
                try save(bundledExample)
                defaults.set(true, forKey: Self.installedFixtureDefaultsKey)
                return
            }
            document = try LocalScheduleStore.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importFile(at url: URL) {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gainedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            _ = importData(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func importData(_ data: Data) -> Bool {
        errorMessage = nil
        noticeMessage = nil

        do {
            let imported = try LocalScheduleStore.decode(data)
            try save(imported)
            noticeMessage = NSLocalizedString("local_schedule_import_success", comment: "")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func publishCurrentDocument() {
        guard let document else { return }
        publish(document)
    }

    func createEmpty() {
        do {
            try save(.empty())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createExample() {
        do {
            try save(try LocalScheduleStore.loadBundledExample() ?? .example())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMetadata(title: String, timeZone: String) {
        guard var document else { return }
        document.title = title
        document.timeZone = timeZone
        do {
            try save(document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upsert(_ event: LocalScheduleDocument.Event) {
        guard var document else { return }
        if let index = document.events.firstIndex(where: { $0.id == event.id }) {
            document.events[index] = event
        } else {
            document.events.append(event)
        }

        do {
            try save(document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ event: LocalScheduleDocument.Event) {
        guard var document else { return }
        document.events.removeAll { $0.id == event.id }
        do {
            try save(document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDocument() {
        do {
            try LocalScheduleStore.delete()
            document = nil
            ClassScheduleWidgetDataStore.clear()
            noticeMessage = NSLocalizedString("local_schedule_delete_success", comment: "")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeNewEvent() -> LocalScheduleDocument.Event {
        let date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return LocalScheduleDocument.Event(
            id: UUID().uuidString.lowercased(),
            date: LocalScheduleFormatting.dayFormatter.string(from: date),
            startTime: "09:00",
            endTime: "10:30",
            title: "",
            type: .other
        )
    }

    func dayTitle(_ rawDate: String) -> String {
        guard let date = LocalScheduleFormatting.dayFormatter.date(from: rawDate) else {
            return rawDate
        }
        return date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .year()
                .locale(Locale.current)
        )
    }

    private func save(_ value: LocalScheduleDocument) throws {
        let normalized = try value.validated().updatingTimestamp()
        try LocalScheduleStore.save(normalized)
        document = normalized
        publish(normalized)
    }

    private func publish(_ document: LocalScheduleDocument) {
        let snapshot = document.widgetSnapshot()
        ClassScheduleWidgetDataStore.save(snapshot)
        WatchScheduleConnectivityService.shared.activate()
        WatchScheduleConnectivityService.shared.send(snapshot)
    }
}
