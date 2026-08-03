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

    static func loadBundledExample(bundle: Bundle = .main) throws -> LocalScheduleDocument? {
        guard let url = bundle.url(forResource: "local_schedule_example", withExtension: "json") else {
            return nil
        }
        return try decode(Data(contentsOf: url))
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
                    subtitle: [event.type.localizedTitle, event.teacherDisplayName]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                        .nilIfBlank,
                    location: event.location?.nilIfBlank,
                    lessonType: event.type.localizedTitle,
                    kind: event.widgetKind
                )
            }

        return SessionScheduleWidgetSnapshot(
            groupName: groupName?.nilIfBlank ?? title,
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

extension LocalScheduleDocument {
    func apiSchedule(teacherID: Int? = nil) -> PublicScheduleResponse {
        let visibleEvents = sortedEvents.filter { event in
            guard !event.isCancelled else { return false }
            guard let teacherID else { return true }
            return event.teacherDetails?.id == teacherID
        }
        let teacher = teacherID.flatMap { identifier in
            visibleEvents.lazy.compactMap(\.teacherDetails).first { $0.id == identifier }
        }
        let group = teacher == nil ? apiGroup : nil
        let regularEvents = visibleEvents.filter { ![.exam, .consultation, .announcement].contains($0.type) }
        let scheduleByWeekday = Dictionary(grouping: regularEvents.compactMap { event in
            event.studyWeekday.map { ($0, event.apiLesson(groupName: groupName ?? title)) }
        }, by: \.0)
            .mapValues { values in values.map(\.1).sorted(by: DisciplineSchedule.sortingComparator) }
        let exams = visibleEvents
            .filter { [.exam, .consultation, .announcement].contains($0.type) }
            .map { $0.apiLesson(groupName: groupName ?? title) }
            .sorted(by: DisciplineSchedule.sortingComparator)
        let examDates = exams.compactMap { $0.lessonDate }

        return PublicScheduleResponse(
            employee: teacher?.apiEmployee,
            group: group,
            exams: exams,
            startDate: validFrom.flatMap(LocalScheduleFormatting.dayFormatter.date(from:))
                ?? visibleEvents.compactMap(\.parsedDate).min(),
            endDate: validThrough.flatMap(LocalScheduleFormatting.dayFormatter.date(from:))
                ?? visibleEvents.compactMap(\.parsedDate).max(),
            startExamsDate: examDates.min(),
            endExamsDate: examDates.max(),
            scheduleByWeekday: scheduleByWeekday,
            previousScheduleByWeekday: [:],
            nextScheduleByWeekday: [:]
        )
    }

    func teacherDirectoryEntry(id: Int) -> ScheduleEmployeeDirectoryEntry? {
        sortedEvents.lazy
            .compactMap(\.teacherDetails)
            .first { $0.id == id }?
            .directoryEntry
    }

    private var apiGroup: StudyGroup {
        StudyGroup(
            name: groupName?.nilIfBlank ?? title,
            facultyId: 20005,
            facultyAbbrev: "ФИТУ",
            facultyName: "Факультет информационных технологий и управления",
            specialityDepartmentEducationFormId: 20835,
            specialityName: "Системы управления информацией",
            specialityAbbrev: "СУИ (АСОИ)",
            course: 3,
            id: 24930,
            calendarId: "a8af76116c15ee1bceb6443744521fb6e284b0e72652f852cd7946b938b102ec@group.calendar.google.com",
            educationDegree: 1
        )
    }
}

private extension LocalScheduleDocument.Event {
    var studyWeekday: StudyWeekday? {
        guard let date = parsedDate else { return nil }
        switch Calendar(identifier: .gregorian).component(.weekday, from: date) {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    func apiLesson(groupName: String) -> DisciplineSchedule {
        let studentGroup = DisciplineStudentGroup(
            specialityName: "Системы управления информацией",
            specialityCode: "6-05-0612-03",
            numberOfStudents: 25,
            name: groupName,
            educationDegree: 1
        )
        return DisciplineSchedule(
            id: id,
            auditories: location?.nilIfBlank.map { [$0] } ?? [],
            endLessonTime: endTime,
            lessonTypeAbbrev: apiLessonType,
            note: type == .announcement ? (note?.nilIfBlank ?? title) : note?.nilIfBlank,
            subgroup: 0,
            startLessonTime: startTime,
            studentGroups: [studentGroup],
            subject: displayTitle,
            subjectFullName: title,
            weekNumbers: [],
            employees: teacherDetails.map { [$0.apiEmployee] } ?? [],
            lessonDate: parsedDate,
            startLessonDate: parsedDate,
            endLessonDate: parsedDate,
            isAnnouncement: type == .announcement,
            isSplit: false
        )
    }

    var apiLessonType: String {
        switch type {
        case .lecture: return "ЛК"
        case .practice: return "ПЗ"
        case .lab: return "ЛР"
        case .exam: return "Экзамен"
        case .consultation: return "Консультация"
        case .announcement: return "Объявление"
        case .other: return "Событие"
        }
    }
}

private extension LocalScheduleDocument.Teacher {
    var apiEmployee: DisciplineEmployee {
        DisciplineEmployee(
            id: id,
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            photoLink: photoLink,
            degree: degree,
            degreeAbbrev: degree,
            rank: rank,
            email: nil,
            urlId: urlId,
            calendarId: calendarId,
            jobPositions: nil,
            isChief: nil
        )
    }

    var directoryEntry: ScheduleEmployeeDirectoryEntry {
        ScheduleEmployeeDirectoryEntry(
            firstName: firstName,
            lastName: lastName,
            middleName: middleName,
            degree: degree,
            rank: rank,
            photoLink: photoLink,
            calendarId: calendarId,
            id: id,
            urlId: urlId,
            fio: fullName
        )
    }
}
