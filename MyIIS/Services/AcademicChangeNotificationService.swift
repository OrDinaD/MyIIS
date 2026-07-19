import BackgroundTasks
import Foundation
import UIKit
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

final class AcademicChangeNotificationService: NSObject {
    static let shared = AcademicChangeNotificationService()

    static let enabledDefaultsKey = "academic_change_notifications_enabled"
    static let lastCheckDefaultsKey = "academic_change_notifications_last_check"

    private static let snapshotDefaultsKey = "academic_change_notifications_snapshot_v1"
    private static let failureCountDefaultsKey = "academic_change_notifications_failure_count"
    private static let lastAttemptDefaultsKey = "academic_change_notifications_last_attempt"
    private static let taskIdentifier = "com.OrDinaD.MyIIS.academic-refresh"
    private static let minimumRefreshDelay: TimeInterval = 30 * 60
    private static let foregroundRefreshInterval: TimeInterval = 5 * 60
    private static let maximumRetryDelay: TimeInterval = 4 * 60 * 60
    private static let maxNotificationItems = 4

    private let apiService = APIService()
    private lazy var dormitoryService = DormitoryService(apiService: apiService)
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
        await checkForChanges(deliverNotifications: false, reason: "initial-baseline")
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
        guard activeCheckTask == nil else {
            logService.log("ℹ️ Academic refresh skipped: another check is already running.")
            return
        }
        if let lastCheck = userDefaults.object(forKey: Self.lastCheckDefaultsKey) as? Date,
           Date().timeIntervalSince(lastCheck) < Self.foregroundRefreshInterval {
            logService.log("ℹ️ Academic refresh skipped: foreground data is still fresh.")
            return
        }

        activeCheckTask = Task { [weak self] in
            guard let self else { return }
            await self.checkForChanges(deliverNotifications: true, reason: "foreground")
            self.activeCheckTask = nil
        }
    }

    func scheduleBackgroundRefresh() {
        guard isEnabled else { return }

        let delay = nextBackgroundRefreshDelay
        let earliestDate = Date(timeIntervalSinceNow: delay)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = earliestDate

        do {
            try BGTaskScheduler.shared.submit(request)
            logService.log(
                "✅ Academic background refresh scheduled no earlier than \(Self.logDateFormatter.string(from: earliestDate))."
            )
        } catch {
            logService.log("⚠️ Failed to schedule academic refresh: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func checkForChanges(deliverNotifications: Bool, reason: String) async -> Bool {
        guard isEnabled else { return false }

        let startedAt = Date()
        userDefaults.set(startedAt, forKey: Self.lastAttemptDefaultsKey)
        logService.log("🔄 Academic refresh started (\(reason)).")

        do {
            let changes = try await fetchChanges(deliverNotifications: deliverNotifications)
            let duration = Date().timeIntervalSince(startedAt)
            logService.log(
                "✅ Academic refresh completed (\(reason)) in \(String(format: "%.2f", duration)) s; changes: \(changes.count)."
            )
            return true
        } catch is CancellationError {
            let duration = Date().timeIntervalSince(startedAt)
            logService.log(
                "ℹ️ Academic refresh cancelled (\(reason)) after \(String(format: "%.2f", duration)) s."
            )
            return false
        } catch {
            let duration = Date().timeIntervalSince(startedAt)
            logService.log(
                "⚠️ Academic refresh failed (\(reason)) after \(String(format: "%.2f", duration)) s: \(error.localizedDescription)"
            )
            return false
        }
    }

    private func fetchChanges(deliverNotifications: Bool) async throws -> [AcademicChangeItem] {
        let personalProfile = try await ensureAuthenticatedIfPossible()

        async let markbookResponse = apiService.getMarkbook()
        async let ratingLessonsResponse = apiService.getPortalGradeBookLessons()
        async let dormitoryApplicationsResponse = fetchDormitoryApplicationsForMonitoring()
        async let penaltiesResponse = fetchPenaltiesForMonitoring()
        async let certificatesResponse = fetchCertificatesForMonitoring()
        async let studyPlanResponse = fetchStudyPlanForMonitoring(group: personalProfile.studentGroup)
        let (markbook, lessons, dormitoryApplications, penalties, certificates, studyPlan) = try await (
            markbookResponse,
            ratingLessonsResponse,
            dormitoryApplicationsResponse,
            penaltiesResponse,
            certificatesResponse,
            studyPlanResponse
        )

        let now = Date()
        let oldSnapshot = loadSnapshot()
        let newSnapshot = AcademicChangeSnapshot(
            markbook: markbook,
            ratingLessons: lessons,
            dormitoryApplications: dormitoryApplications,
            penalties: penalties,
            certificates: certificates,
            studyPlan: studyPlan,
            previousSnapshot: oldSnapshot
        )
        GradebookCacheStore.save(markbook: markbook, currentCourse: personalProfile.course, updatedAt: now)
        if let oldSnapshot {
            for applicationID in newSnapshot.newlySettledDormitoryApplicationIDs(since: oldSnapshot) {
                DormitorySettlementRevealStore.markPending(
                    applicationID: applicationID,
                    for: AuthenticationService.shared.currentUser?.id,
                    userDefaults: userDefaults
                )
            }
        }
        saveSnapshot(newSnapshot)
        updateWidgetSnapshot(with: newSnapshot)
        userDefaults.set(now, forKey: Self.lastCheckDefaultsKey)

        guard deliverNotifications, let oldSnapshot else { return [] }
        let changes = newSnapshot.changes(since: oldSnapshot)
        if !changes.isEmpty {
            await deliverNotification(for: changes)
        }
        return changes
    }

}

private extension AcademicChangeNotificationService {
    func registerBackgroundRefreshTask() {
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
        logService.log("🌙 Academic background refresh was launched by iOS.")
        scheduleBackgroundRefresh()

        let refreshTask = Task { [weak self] in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }

            let success = await self.checkForChanges(deliverNotifications: true, reason: "background")
            self.recordBackgroundResult(success: success)
            self.scheduleBackgroundRefresh()
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = { [weak self] in
            self?.logService.log("⏳ Academic background refresh expired; cancelling requests.")
            refreshTask.cancel()
        }
    }

    private var nextBackgroundRefreshDelay: TimeInterval {
        let failureCount = max(0, userDefaults.integer(forKey: Self.failureCountDefaultsKey))
        guard failureCount > 0 else { return Self.minimumRefreshDelay }

        let multiplier = pow(2.0, Double(min(failureCount, 3)))
        return min(Self.minimumRefreshDelay * multiplier, Self.maximumRetryDelay)
    }

    private func recordBackgroundResult(success: Bool) {
        if success {
            userDefaults.set(0, forKey: Self.failureCountDefaultsKey)
        } else {
            let currentCount = userDefaults.integer(forKey: Self.failureCountDefaultsKey)
            userDefaults.set(min(currentCount + 1, 3), forKey: Self.failureCountDefaultsKey)
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
        let isSettlementUpdate = changes.contains(where: isDormitorySettlementUpdate)
        let content = UNMutableNotificationContent()
        content.title = isSettlementUpdate
            ? NSLocalizedString("dormitory_notification_status_title", comment: "")
            : notificationTitle(for: changes)
        content.body = isSettlementUpdate
            ? NSLocalizedString("dormitory_notification_status_body", comment: "")
            : notificationBody(for: shownChanges, totalCount: changes.count)
        content.sound = .default
        content.threadIdentifier = isSettlementUpdate ? "dormitory-status" : "academic-updates"
        content.categoryIdentifier = isSettlementUpdate ? "dormitory-status" : "academic-updates"
        if isSettlementUpdate {
            content.userInfo = ["destination": AppSection.dormitory.rawValue]
        }

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

    private func isDormitorySettlementUpdate(_ change: AcademicChangeItem) -> Bool {
        change.source == .dormitory &&
            change.signature.contains("|status|") &&
            change.value.localizedCaseInsensitiveContains(DormitoryApplicationStatus.settled.rawValue)
    }

    private func notificationTitle(for changes: [AcademicChangeItem]) -> String {
        let hasMarkbook = changes.contains { $0.source == .markbook }
        let hasRating = changes.contains { $0.source == .rating }
        let hasOmissions = changes.contains { $0.source == .omission }
        let hasDormitory = changes.contains { $0.source == .dormitory }
        let hasPenalty = changes.contains { $0.source == .penalty }
        let hasCertificate = changes.contains { $0.source == .certificate }
        let hasSchedule = changes.contains { $0.source == .schedule }

        if hasSchedule {
            return "Обновление расписания"
        }

        if hasCertificate && !hasMarkbook && !hasRating && !hasOmissions && !hasDormitory && !hasPenalty {
            return "Обновление справок"
        }

        if hasPenalty && !hasMarkbook && !hasRating && !hasOmissions && !hasDormitory && !hasCertificate {
            return "Взыскания и поощрения"
        }

        if hasDormitory && !hasMarkbook && !hasRating && !hasOmissions && !hasPenalty && !hasCertificate {
            return "Общежитие обновлено"
        }

        if hasOmissions && !hasMarkbook && !hasRating && !hasDormitory && !hasPenalty && !hasCertificate {
            return "Новые пропуски"
        }

        if hasDormitory || hasOmissions || hasPenalty || hasCertificate {
            return "Личный кабинет обновлён"
        }

        switch (hasMarkbook, hasRating) {
        case (true, true):
            return "Новые отметки"
        case (true, false):
            return "Зачётка обновлена"
        case (false, true):
            return "Рейтинг обновлён"
        case (false, false):
            return "Личный кабинет обновлён"
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

    private func ensureAuthenticatedIfPossible() async throws -> PersonalProfile {
        do {
            return try await apiService.getPersonalProfile()
        } catch APIError.unauthorized {
            guard let credentials = try credentialStore.retrieve() else {
                throw APIError.unauthorized(message: "Не удалось восстановить сессию")
            }

            _ = try await apiService.login(username: credentials.username, password: credentials.password)
            return try await apiService.getPersonalProfile()
        }
    }

    private func fetchDormitoryApplicationsForMonitoring() async -> [DormitoryQueueApplication]? {
        do {
            return try await dormitoryService.fetchApplications()
        } catch is CancellationError {
            return nil
        } catch {
            logService.log("⚠️ Dormitory change check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchPenaltiesForMonitoring() async -> [ServiceJSONObject]? {
        do {
            let api = ServiceEndpointsAPI()
            return try await api.fetchPenalties()
        } catch is CancellationError {
            return nil
        } catch {
            logService.log("⚠️ Penalties change check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchCertificatesForMonitoring() async -> [CertificateRequest]? {
        do {
            let service = StudyService()
            return try await service.fetchDashboard().certificates
        } catch is CancellationError {
            return nil
        } catch {
            logService.log("⚠️ Certificates change check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchStudyPlanForMonitoring(group: String?) async -> StudyPlan? {
        guard let group = group, !group.isEmpty else { return nil }
        do {
            return try await apiService.getStudyPlan(for: group)
        } catch is CancellationError {
            return nil
        } catch {
            logService.log("⚠️ Study plan change check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func updateWidgetSnapshot(with snapshot: AcademicChangeSnapshot) {
        let totalHours = snapshot.omissionItems.reduce(0) { $0 + $1.hours }
        let previousHours = MyIISDataStore.loadData()?.unexcusedAbsences

        MyIISDataStore.update(unexcusedAbsences: totalHours)
        AttendanceWidgetDataStore.save(
            AttendanceWidgetSnapshot(
                monthTitle: "семестр",
                unexcusedHours: totalHours,
                updatedAt: Date()
            )
        )

#if canImport(WidgetKit)
        if previousHours != totalHours {
            WidgetCenter.shared.reloadTimelines(ofKind: AttendanceWidgetConstants.kind)
        }
#endif
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Self.enabledDefaultsKey)
        if !enabled {
            userDefaults.set(0, forKey: Self.failureCountDefaultsKey)
        }
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard
            response.actionIdentifier == UNNotificationDefaultActionIdentifier,
            let destination = response.notification.request.content.userInfo["destination"] as? String,
            let section = AppSection(rawValue: destination)
        else {
            return
        }

        await MainActor.run {
            AppRouter.shared.navigate(to: section)
        }
    }
}
