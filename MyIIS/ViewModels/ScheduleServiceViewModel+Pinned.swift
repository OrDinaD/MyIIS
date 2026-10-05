import Foundation

extension ScheduleServiceViewModel {
    static func loadStoredTeachers(forKey key: String, from defaults: UserDefaults) -> [PinnedTeacher] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PinnedTeacher].self, from: data)) ?? []
    }

    private static func saveStoredTeachers(_ teachers: [PinnedTeacher], forKey key: String, in defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(teachers) {
            defaults.set(data, forKey: key)
        }
    }

    func persistGroupSelection(_ group: String) {
        defaults.set(group, forKey: Self.lastGroupDefaultsKey)
        defaults.removeObject(forKey: Self.lastTeacherURLIDDefaultsKey)
        defaults.removeObject(forKey: Self.lastTeacherNameDefaultsKey)
    }

    func persistTeacherSelection(urlId: String, displayName: String) {
        defaults.set(urlId, forKey: Self.lastTeacherURLIDDefaultsKey)
        defaults.set(displayName, forKey: Self.lastTeacherNameDefaultsKey)
    }

    // MARK: - Pinned & Recent Management

    func isGroupPinned(_ name: String) -> Bool {
        pinnedGroupNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func togglePinnedGroup(_ group: StudyGroup) {
        togglePinnedGroupName(group.name)
    }

    func togglePinnedGroupName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if pinnedGroupNames.contains(trimmed) {
            pinnedGroupNames.removeAll { $0 == trimmed }
        } else {
            pinnedGroupNames.insert(trimmed, at: 0)
        }

        pinnedGroupNames = Array(pinnedGroupNames.prefix(12))
        defaults.set(pinnedGroupNames, forKey: Self.pinnedGroupsDefaultsKey)
    }

    func pinnedGroupAlias(for groupName: String) -> String? {
        let group = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return pinnedGroupAliases[group]?.nilIfBlank
    }

    func pinnedGroupDisplayName(for groupName: String) -> String {
        pinnedGroupAlias(for: groupName) ?? groupName
    }

    func pinnedGroupMenuTitle(for groupName: String) -> String {
        guard let alias = pinnedGroupAlias(for: groupName) else { return groupName }
        return "\(alias) (\(groupName))"
    }

    func setPinnedGroupAlias(_ alias: String?, for groupName: String) {
        let group = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !group.isEmpty, isGroupPinned(group) else { return }

        if let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines), !alias.isEmpty {
            pinnedGroupAliases[group] = alias
        } else {
            pinnedGroupAliases.removeValue(forKey: group)
        }
        defaults.set(pinnedGroupAliases, forKey: Self.pinnedGroupAliasesDefaultsKey)
    }

    func isTeacherPinned(_ urlId: String) -> Bool {
        pinnedTeachers.contains(where: { $0.urlId == urlId })
    }

    func togglePinnedTeacher(_ employee: ScheduleEmployeeDirectoryEntry) {
        guard let urlId = employee.urlId, !urlId.isEmpty else { return }
        togglePinnedTeacher(PinnedTeacher(urlId: urlId, name: employee.displayName, photoLink: employee.photoLink))
    }

    func togglePinnedTeacher(_ teacher: PinnedTeacher) {
        if let idx = pinnedTeachers.firstIndex(where: { $0.urlId == teacher.urlId }) {
            pinnedTeachers.remove(at: idx)
        } else {
            pinnedTeachers.insert(teacher, at: 0)
        }
        pinnedTeachers = Array(pinnedTeachers.prefix(12))
        Self.saveStoredTeachers(pinnedTeachers, forKey: Self.pinnedTeachersDefaultsKey, in: defaults)
    }

    func recordRecentGroup(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentGroupNames.removeAll { $0 == trimmed }
        recentGroupNames.insert(trimmed, at: 0)
        recentGroupNames = Array(recentGroupNames.prefix(6))
        defaults.set(recentGroupNames, forKey: Self.recentGroupsDefaultsKey)
    }

    func recordRecentTeacher(_ employee: ScheduleEmployeeDirectoryEntry) {
        guard let urlId = employee.urlId, !urlId.isEmpty else { return }
        let teacher = PinnedTeacher(urlId: urlId, name: employee.displayName, photoLink: employee.photoLink)
        recentTeachers.removeAll { $0.urlId == urlId }
        recentTeachers.insert(teacher, at: 0)
        recentTeachers = Array(recentTeachers.prefix(6))
        Self.saveStoredTeachers(recentTeachers, forKey: Self.recentTeachersDefaultsKey, in: defaults)
    }
}
