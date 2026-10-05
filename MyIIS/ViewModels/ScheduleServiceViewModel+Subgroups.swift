import Foundation

extension ScheduleServiceViewModel {
    func sanitizeSubgroupFilter() {
        guard mode == .group else {
            subgroupFilter = .all
            return
        }
        if !subgroupFilters.contains(subgroupFilter) {
            subgroupFilter = .all
        }
    }

    func isOtherSubgroupLesson(_ lesson: DisciplineSchedule) -> Bool {
        if let subject = subjectSubgroup(for: lesson) {
            return !matchesSubjectSubgroup(lesson, subject: subject)
        }
        guard case .subgroup(let selected) = subgroupFilter else { return false }
        return lesson.subgroup > 0 && lesson.subgroup != selected
    }

    func refreshSubgroupPresentation() {
        rebuildContinuousTimeline(reset: true)
    }

    func shouldKeepLesson(_ lesson: DisciplineSchedule) -> Bool {
        if subjectSubgroup(for: lesson) != nil { return shouldKeepLanguageLesson(lesson) }
        guard case .subgroup(let value) = subgroupFilter else { return true }
        if lesson.subgroup == 0 || lesson.subgroup == value {
            return true
        }
        let raw = defaults.string(forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        let display = raw.flatMap(ScheduleOtherSubgroupDisplay.init(rawValue:)) ?? .compact
        return display != .hidden
    }

    var showsLanguageSubgroupPicker: Bool {
        mode == .group && displayMode != .exams && languageSubgroupOptions.count > 1
    }

    func subjectSubgroup(for lesson: DisciplineSchedule) -> ScheduleSubjectSubgroups? {
        guard mode == .group, lesson.subgroup == 0 else { return nil }
        let key = Self.subjectKey(lesson)
        return subjectSubgroups.first { $0.id == key && $0.lessonTypes.contains(lesson.lessonTypeAbbrev) }
    }

    func selectedTeacherID(for subject: ScheduleSubjectSubgroups) -> Int? {
        let selected = Self.isLanguageSubject(subject.id)
            ? languageSubgroupTeacherID : subjectSubgroupTeacherIDs[subject.id]
        return selected.flatMap { id in subject.options.contains { $0.id == id } ? id : nil }
    }

    func selectTeacher(_ id: Int?, for subject: ScheduleSubjectSubgroups) {
        if Self.isLanguageSubject(subject.id) {
            languageSubgroupTeacherID = id
        } else {
            subjectSubgroupTeacherIDs[subject.id] = id
            if mode == .group, let activeGroupNumber {
                defaults.set(subjectSubgroupTeacherIDs, forKey: Self.subjectSubgroupDefaultsKey + "." + activeGroupNumber)
            }
            refreshSubgroupPresentation()
            if let schedule {
                updateClassScheduleWidgetSnapshot(from: schedule)
                updateSessionScheduleWidgetSnapshot(from: schedule)
            }
        }
    }

    func matchesSubjectSubgroup(_ lesson: DisciplineSchedule, subject: ScheduleSubjectSubgroups) -> Bool {
        guard let selected = selectedTeacherID(for: subject), !lesson.employees.isEmpty else { return true }
        return lesson.employees.contains { $0.id == selected }
    }

    func shouldKeepLanguageLesson(_ lesson: DisciplineSchedule) -> Bool {
        guard let subject = subjectSubgroup(for: lesson),
              !matchesSubjectSubgroup(lesson, subject: subject) else { return true }
        let display = defaults.string(forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
            .flatMap(ScheduleOtherSubgroupDisplay.init(rawValue:)) ?? .compact
        return display != .hidden
    }

    func restoreLanguageSubgroup(for groupNumber: String) {
        isRestoringLanguageSubgroup = true
        defer { isRestoringLanguageSubgroup = false }
        subjectSubgroupTeacherIDs = defaults.dictionary(
            forKey: Self.subjectSubgroupDefaultsKey + "." + groupNumber
        ) as? [String: Int] ?? [:]
        let stored = defaults.object(forKey: Self.languageSubgroupDefaultsKey + "." + groupNumber) as? Int
        languageSubgroupTeacherID = stored.flatMap { id in
            languageSubgroupOptions.contains(where: { $0.id == id }) ? id : nil
        }
    }

    nonisolated static func subjectKey(_ lesson: DisciplineSchedule) -> String {
        let fullName = lesson.subjectFullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (fullName.isEmpty ? lesson.subject : fullName).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated static func isLanguageSubject(_ key: String) -> Bool {
        key == "иностранный язык" || key == "английский язык" || key == "иняз"
    }

    nonisolated static func isLanguageLesson(_ lesson: DisciplineSchedule) -> Bool {
        lesson.subgroup == 0 && isLanguageSubject(subjectKey(lesson))
    }

    /// Offer independent choices only for simultaneous, unnumbered classes with distinct teachers.
    static func makeSubjectSubgroups(_ schedule: PublicScheduleResponse?) -> [ScheduleSubjectSubgroups] {
        guard let schedule else { return [] }
        var parallelSubjects: Set<String> = []
        var parallelTypes: [String: Set<String>] = [:]
        var titles: [String: String] = [:]
        for day in schedule.orderedDays {
            let lessons = day.lessons.filter { $0.subgroup == 0 && !$0.isAnnouncement }
            for lesson in lessons {
                let key = subjectKey(lesson)
                titles[key] = lesson.subjectFullName?.nilIfBlank ?? lesson.subject
                if lessons.contains(where: { other in
                    subjectKey(other) == key && other.lessonTypeAbbrev == lesson.lessonTypeAbbrev
                        && other.startLessonTime == lesson.startLessonTime
                        && other.endLessonTime == lesson.endLessonTime
                        && other.lessonDate == lesson.lessonDate
                        && (lesson.startLessonDate ?? .distantPast) <= (other.endLessonDate ?? .distantFuture)
                        && (other.startLessonDate ?? .distantPast) <= (lesson.endLessonDate ?? .distantFuture)
                        && (other.weekNumbers.isEmpty || lesson.weekNumbers.isEmpty
                            || !Set(other.weekNumbers).isDisjoint(with: lesson.weekNumbers))
                        && !other.employees.isEmpty && !lesson.employees.isEmpty
                        && Set(other.employees.map(\.id)).isDisjoint(with: lesson.employees.map(\.id))
                }) {
                    parallelSubjects.insert(key)
                    parallelTypes[key, default: []].insert(lesson.lessonTypeAbbrev)
                }
            }
        }
        return parallelSubjects.sorted().compactMap { key in
            let matchingLessons = schedule.orderedDays.flatMap(\.lessons).filter {
                subjectKey($0) == key && parallelTypes[key]?.contains($0.lessonTypeAbbrev) == true
            }
            let teachers = matchingLessons.flatMap(\.employees).reduce(into: [Int: String]()) { result, teacher in
                if !teacher.fullName.isEmpty { result[teacher.id] = teacher.fullName }
            }
            guard teachers.count > 1 else { return nil }
            let options = teachers.keys.sorted().enumerated().map { index, id in
                ScheduleLanguageSubgroup(id: id, number: index + 1, teacherName: teachers[id] ?? "")
            }
            return ScheduleSubjectSubgroups(
                id: key, title: titles[key] ?? key, options: options, lessonTypes: parallelTypes[key] ?? []
            )
        }
    }

    func persistDisplayMode() {
        defaults.set(displayMode.rawValue, forKey: Self.displayModeDefaultsKey)
    }

    func restoredSubgroupFilter(for groupNumber: String) -> ScheduleSubgroupFilter {
        let key = Self.subgroupFilterByGroupDefaultsKey + "." + groupNumber
        if let value = defaults.object(forKey: key) as? Int {
            return value > 0 ? .subgroup(value) : .all
        }

        // Transfer the previous global choice only to the group last opened before this update.
        if defaults.string(forKey: Self.lastGroupDefaultsKey) == groupNumber,
           let value = defaults.object(forKey: Self.subgroupFilterDefaultsKey) as? Int {
            defaults.set(value, forKey: key)
            defaults.removeObject(forKey: Self.subgroupFilterDefaultsKey)
            return value > 0 ? .subgroup(value) : .all
        }
        return .all
    }

    func persistSubgroupFilter() {
        guard mode == .group, let activeGroupNumber else { return }
        let key = Self.subgroupFilterByGroupDefaultsKey + "." + activeGroupNumber
        switch subgroupFilter {
        case .all:
            defaults.set(0, forKey: key)
        case .subgroup(let value):
            defaults.set(value, forKey: key)
        }
    }

    var subgroupFilters: [ScheduleSubgroupFilter] {
        guard let schedule, !isSchedulePublicationPending else { return [.all] }
        let lessonSubgroups = schedule.orderedDays
            .flatMap(\.lessons)
            .map(\.subgroup)
        let examSubgroups = schedule.exams.map(\.subgroup)
        let allSubgroups = (lessonSubgroups + examSubgroups).filter { $0 > 0 }
        let unique = Array(Set(allSubgroups)).sorted()
        guard !unique.isEmpty else { return [.all] }
        return [.all] + unique.map { .subgroup($0) }
    }

    var showsSubgroupPicker: Bool {
        mode != .teacher && displayMode != .exams && subgroupFilters.count > 1
    }
}
