import Foundation

enum LocalScheduleStore {
    private static let directoryName = "LocalSchedules"
    private static let fileName = "current.json"

    static func load() throws -> LocalScheduleDocument? {
        guard let url = currentFileURL(), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> LocalScheduleDocument {
        let decoder = JSONDecoder()
        return try decoder.decode(LocalScheduleDocument.self, from: data).validated()
    }

    @discardableResult
    static func save(_ document: LocalScheduleDocument) throws -> URL {
        let normalized = try document.validated().updatingTimestamp()
        guard let url = currentFileURL(createDirectory: true) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(normalized)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func delete() throws {
        guard let url = currentFileURL(), FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    static func currentFileURL(createDirectory: Bool = false) -> URL? {
        let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        guard let baseURL else { return nil }
        let directoryURL = baseURL.appendingPathComponent(directoryName, isDirectory: true)
        if createDirectory {
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
        return directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }
}

extension LocalScheduleDocument {
    func widgetSnapshot() -> SessionScheduleWidgetSnapshot {
        let widgetEvents = sortedEvents
            .filter { !$0.isCancelled }
            .compactMap { event -> SessionScheduleWidgetSnapshot.Event? in
                guard let date = event.parsedDate else { return nil }
                return SessionScheduleWidgetSnapshot.Event(
                    id: event.id,
                    date: date,
                    startTime: event.startTime,
                    endTime: event.endTime,
                    title: event.displayTitle,
                    subtitle: [event.type.localizedTitle, event.teacher?.nilIfBlank]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                        .nilIfBlank,
                    location: event.location?.nilIfBlank,
                    lessonType: event.type.localizedTitle,
                    kind: event.widgetKind
                )
            }

        return SessionScheduleWidgetSnapshot(
            groupName: title,
            startDate: validFrom.flatMap(LocalScheduleFormatting.dayFormatter.date(from:)),
            endDate: validThrough.flatMap(LocalScheduleFormatting.dayFormatter.date(from:)),
            events: widgetEvents,
            updatedAt: ISO8601DateFormatter().date(from: updatedAt ?? "") ?? .now
        )
    }
}

private extension LocalScheduleDocument.Event {
    var widgetKind: SessionScheduleWidgetEventKind {
        switch type {
        case .announcement:
            return .announcement
        case .exam:
            return .exam
        case .consultation:
            return .consultation
        case .lecture, .practice, .lab, .other:
            return .other
        }
    }
}
