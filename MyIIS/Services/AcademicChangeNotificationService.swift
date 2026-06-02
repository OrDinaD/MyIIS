import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

final class AcademicChangeNotificationService: NSObject {
    static let shared = AcademicChangeNotificationService()

    static let enabledDefaultsKey = "academic_change_notifications_enabled"
    static let lastCheckDefaultsKey = "academic_change_notifications_last_check"

    private static let snapshotDefaultsKey = "academic_change_notifications_snapshot_v1"
    private static let taskIdentifier = "com.OrDinaD.MyIIS.academic-refresh"
    private static let minimumRefreshDelay: TimeInterval = 30 * 60
    private static let maxNotificationItems = 4

    private let apiService = APIService()
    private let credentialStore = CredentialStore.shared
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    private let logService = LogService.shared

    private var didRegisterBackgroundTask = false
    private var activeCheckTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    var isEnabled: Bool {
        userDefaults.bool(forKey: Self.enabledDefaultsKey)
    }

    func configureAtLaunch() {
        notificationCenter.delegate = self
        registerBackgroundRefreshTask()

        if isEnabled {
            scheduleBackgroundRefresh()
        }
    }

    @discardableResult
    func enableFromUserAction() async -> Bool {
        guard await requestNotificationAuthorizationIfNeeded() else {
            setEnabled(false)
            return false
        }

        setEnabled(true)
        await checkForChanges(deliverNotifications: false)
        scheduleBackgroundRefresh()
        return true
    }

    func disableFromUserAction() {
        setEnabled(false)
        activeCheckTask?.cancel()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }

    func checkWhenAppBecomesActive() {
        guard isEnabled else { return }

        activeCheckTask?.cancel()
        activeCheckTask = Task { [weak self] in
            await self?.checkForChanges(deliverNotifications: true)
        }
    }

    func scheduleBackgroundRefresh() {
        guard isEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumRefreshDelay)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logService.log("⚠️ Failed to schedule academic refresh: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func checkForChanges(deliverNotifications: Bool) async -> Bool {
        guard isEnabled else { return false }

        do {
            try await ensureAuthenticatedIfPossible()

            async let markbookResponse = apiService.getMarkbook()
            async let ratingLessonsResponse = apiService.getPortalGradeBookLessons()
            let (markbook, lessons) = try await (markbookResponse, ratingLessonsResponse)

            let newSnapshot = AcademicChangeSnapshot(markbook: markbook, ratingLessons: lessons)
            let oldSnapshot = loadSnapshot()
            saveSnapshot(newSnapshot)
            userDefaults.set(Date(), forKey: Self.lastCheckDefaultsKey)

            guard deliverNotifications, let oldSnapshot else {
                return true
            }

            let changes = newSnapshot.changes(since: oldSnapshot)
            if !changes.isEmpty {
                await deliverNotification(for: changes)
            }

            return true
        } catch is CancellationError {
            return false
        } catch {
            logService.log("⚠️ Academic change check failed: \(error.localizedDescription)")
            return false
        }
    }

    private func registerBackgroundRefreshTask() {
        guard !didRegisterBackgroundTask else { return }

        didRegisterBackgroundTask = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handleAppRefresh(refreshTask)
        }

        if !didRegisterBackgroundTask {
            logService.log("⚠️ Failed to register academic background refresh task.")
        }
    }

    private func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        let refreshTask = Task { [weak self] in
            let success = await self?.checkForChanges(deliverNotifications: true) ?? false
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }
    }

    private func requestNotificationAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                logService.log("⚠️ Notification authorization failed: \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func deliverNotification(for changes: [AcademicChangeItem]) async {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let shownChanges = Array(changes.prefix(Self.maxNotificationItems))
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: changes)
        content.body = notificationBody(for: shownChanges, totalCount: changes.count)
        content.sound = .default
        content.threadIdentifier = "academic-updates"
        content.categoryIdentifier = "academic-updates"

        let request = UNNotificationRequest(
            identifier: "academic-updates-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            logService.log("⚠️ Failed to deliver academic notification: \(error.localizedDescription)")
        }
    }

    private func notificationTitle(for changes: [AcademicChangeItem]) -> String {
        let hasMarkbook = changes.contains { $0.source == .markbook }
        let hasRating = changes.contains { $0.source == .rating }

        switch (hasMarkbook, hasRating) {
        case (true, true):
            return "Новые отметки"
        case (true, false):
            return "Зачётка обновлена"
        case (false, true):
            return "Рейтинг обновлён"
        case (false, false):
            return "Учебные данные обновлены"
        }
    }

    private func notificationBody(for changes: [AcademicChangeItem], totalCount: Int) -> String {
        let lines = changes.map { item in
            "\(item.subject): \(item.value)"
        }

        if totalCount > changes.count {
            return (lines + ["И ещё: \(totalCount - changes.count)"]).joined(separator: "\n")
        }

        return lines.joined(separator: "\n")
    }

    private func ensureAuthenticatedIfPossible() async throws {
        do {
            _ = try await apiService.getPersonalProfile()
        } catch APIError.unauthorized {
            guard let credentials = try credentialStore.retrieve() else {
                throw APIError.unauthorized(message: "Не удалось восстановить сессию")
            }

            _ = try await apiService.login(username: credentials.username, password: credentials.password)
            _ = try await apiService.getPersonalProfile()
        }
    }

    private func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Self.enabledDefaultsKey)
    }

    private func loadSnapshot() -> AcademicChangeSnapshot? {
        guard let data = UserDefaultsPayloadStore.load(forKey: Self.snapshotDefaultsKey, from: userDefaults) else {
            return nil
        }

        return try? JSONDecoder().decode(AcademicChangeSnapshot.self, from: data)
    }

    private func saveSnapshot(_ snapshot: AcademicChangeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(data, forKey: Self.snapshotDefaultsKey, in: userDefaults)
    }
}

extension AcademicChangeNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

private struct AcademicChangeSnapshot: Codable, Equatable {
    let markbookItems: [AcademicChangeItem]
    let ratingItems: [AcademicChangeItem]
    let capturedAt: Date

    init(markbook: MarkbookResponse, ratingLessons: [PortalGradeBookLesson]) {
        self.markbookItems = Self.makeMarkbookItems(from: markbook)
        self.ratingItems = Self.makeRatingItems(from: ratingLessons)
        self.capturedAt = Date()
    }

    func changes(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldKeys = Set((oldSnapshot.markbookItems + oldSnapshot.ratingItems).map(\.signature))
        return (markbookItems + ratingItems)
            .filter { !oldKeys.contains($0.signature) }
            .sorted(by: AcademicChangeItem.defaultSort)
    }

    private static func makeMarkbookItems(from markbook: MarkbookResponse) -> [AcademicChangeItem] {
        markbook.markPages.flatMap { semester, page in
            page.marks.map { mark in
                AcademicChangeItem(
                    signature: [
                        "markbook",
                        semester,
                        mark.subject,
                        mark.formOfControl,
                        mark.date ?? "",
                        mark.mark
                    ].joined(separator: "|"),
                    source: .markbook,
                    subject: mark.subject,
                    value: mark.mark,
                    date: mark.date,
                    context: mark.formOfControl
                )
            }
        }
    }

    private static func makeRatingItems(from lessons: [PortalGradeBookLesson]) -> [AcademicChangeItem] {
        lessons.flatMap { lesson in
            lesson.marks.enumerated().map { offset, mark in
                AcademicChangeItem(
                    signature: [
                        "rating",
                        String(lesson.id),
                        lesson.lessonNameAbbrev,
                        lesson.dateString,
                        lesson.lessonTypeAbbrev,
                        lesson.controlPoint,
                        String(offset),
                        String(mark)
                    ].joined(separator: "|"),
                    source: .rating,
                    subject: lesson.lessonNameAbbrev,
                    value: String(mark),
                    date: lesson.dateString,
                    context: lesson.controlPoint.isEmpty ? lesson.lessonTypeAbbrev : lesson.controlPoint
                )
            }
        }
    }
}

private struct AcademicChangeItem: Codable, Hashable {
    let signature: String
    let source: AcademicChangeSource
    let subject: String
    let value: String
    let date: String?
    let context: String

    static func defaultSort(lhs: AcademicChangeItem, rhs: AcademicChangeItem) -> Bool {
        let lhsDate = lhs.date ?? ""
        let rhsDate = rhs.date ?? ""
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        return lhs.subject.localizedCaseInsensitiveCompare(rhs.subject) == .orderedAscending
    }
}

private enum AcademicChangeSource: String, Codable {
    case markbook
    case rating
}
