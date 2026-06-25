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
    private static let taskIdentifier = "com.OrDinaD.MyIIS.academic-refresh"
    private static let minimumRefreshDelay: TimeInterval = 30 * 60
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
            let personalProfile = try await ensureAuthenticatedIfPossible()

            async let markbookResponse = apiService.getMarkbook()
            async let ratingLessonsResponse = apiService.getPortalGradeBookLessons()
            async let dormitoryApplicationsResponse = fetchDormitoryApplicationsForMonitoring()
            async let penaltiesResponse = fetchPenaltiesForMonitoring()
            async let certificatesResponse = fetchCertificatesForMonitoring()
            let (markbook, lessons, dormitoryApplications, penalties, certificates) = try await (
                markbookResponse,
                ratingLessonsResponse,
                dormitoryApplicationsResponse,
                penaltiesResponse,
                certificatesResponse
            )
            let now = Date()

            let oldSnapshot = loadSnapshot()
            let newSnapshot = AcademicChangeSnapshot(
                markbook: markbook,
                ratingLessons: lessons,
                dormitoryApplications: dormitoryApplications,
                penalties: penalties,
                certificates: certificates,
                previousSnapshot: oldSnapshot
            )
            GradebookCacheStore.save(markbook: markbook, currentCourse: personalProfile.course, updatedAt: now)
            saveSnapshot(newSnapshot)
            updateWidgetSnapshot(with: newSnapshot)
            userDefaults.set(now, forKey: Self.lastCheckDefaultsKey)

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
        let hasOmissions = changes.contains { $0.source == .omission }
        let hasDormitory = changes.contains { $0.source == .dormitory }
        let hasPenalty = changes.contains { $0.source == .penalty }
        let hasCertificate = changes.contains { $0.source == .certificate }

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
    let omissionItems: [AcademicOmissionItem]
    let dormitoryItems: [DormitoryApplicationItem]
    let penaltyItems: [PenaltyNotificationItem]
    let certificateItems: [CertificateNotificationItem]
    let hasDormitoryBaseline: Bool
    let hasPenaltiesBaseline: Bool
    let hasCertificatesBaseline: Bool
    let capturedAt: Date

    private enum CodingKeys: String, CodingKey {
        case markbookItems
        case ratingItems
        case omissionItems
        case dormitoryItems
        case penaltyItems
        case certificateItems
        case hasDormitoryBaseline
        case hasPenaltiesBaseline
        case hasCertificatesBaseline
        case capturedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.markbookItems = try container.decode([AcademicChangeItem].self, forKey: .markbookItems)
        self.ratingItems = try container.decode([AcademicChangeItem].self, forKey: .ratingItems)
        self.omissionItems = try container.decodeIfPresent([AcademicOmissionItem].self, forKey: .omissionItems) ?? []
        self.dormitoryItems = try container.decodeIfPresent([DormitoryApplicationItem].self, forKey: .dormitoryItems) ?? []
        self.penaltyItems = try container.decodeIfPresent([PenaltyNotificationItem].self, forKey: .penaltyItems) ?? []
        self.certificateItems = try container.decodeIfPresent([CertificateNotificationItem].self, forKey: .certificateItems) ?? []
        self.hasDormitoryBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasDormitoryBaseline) ?? false
        self.hasPenaltiesBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasPenaltiesBaseline) ?? false
        self.hasCertificatesBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasCertificatesBaseline) ?? false
        self.capturedAt = try container.decode(Date.self, forKey: .capturedAt)
    }

    init(
        markbook: MarkbookResponse,
        ratingLessons: [PortalGradeBookLesson],
        dormitoryApplications: [DormitoryQueueApplication]?,
        penalties: [ServiceJSONObject]?,
        certificates: [CertificateRequest]?,
        previousSnapshot: AcademicChangeSnapshot?
    ) {
        self.markbookItems = Self.makeMarkbookItems(from: markbook)
        self.ratingItems = Self.makeRatingItems(from: ratingLessons)
        self.omissionItems = Self.makeOmissionItems(from: ratingLessons)

        if let dormitoryApplications {
            self.dormitoryItems = Self.makeDormitoryItems(from: dormitoryApplications)
            self.hasDormitoryBaseline = true
        } else {
            self.dormitoryItems = previousSnapshot?.dormitoryItems ?? []
            self.hasDormitoryBaseline = previousSnapshot?.hasDormitoryBaseline == true
        }
        
        if let penalties {
            self.penaltyItems = Self.makePenaltyItems(from: penalties)
            self.hasPenaltiesBaseline = true
        } else {
            self.penaltyItems = previousSnapshot?.penaltyItems ?? []
            self.hasPenaltiesBaseline = previousSnapshot?.hasPenaltiesBaseline == true
        }

        if let certificates {
            self.certificateItems = Self.makeCertificateItems(from: certificates)
            self.hasCertificatesBaseline = true
        } else {
            self.certificateItems = previousSnapshot?.certificateItems ?? []
            self.hasCertificatesBaseline = previousSnapshot?.hasCertificatesBaseline == true
        }

        self.capturedAt = Date()
    }

    func changes(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldKeys = Set((oldSnapshot.markbookItems + oldSnapshot.ratingItems).map(\.signature))
        let gradeChanges = (markbookItems + ratingItems)
            .filter { !oldKeys.contains($0.signature) }

        let dormitoryChanges = hasDormitoryBaseline && oldSnapshot.hasDormitoryBaseline
            ? dormitoryChanges(since: oldSnapshot)
            : []
            
        let penChanges = hasPenaltiesBaseline && oldSnapshot.hasPenaltiesBaseline
            ? penaltyChanges(since: oldSnapshot)
            : []
            
        let certChanges = hasCertificatesBaseline && oldSnapshot.hasCertificatesBaseline
            ? certificateChanges(since: oldSnapshot)
            : []

        return (gradeChanges + omissionChanges(since: oldSnapshot) + dormitoryChanges + penChanges + certChanges)
            .sorted(by: AcademicChangeItem.defaultSort)
    }

    private func penaltyChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldItemsById = Dictionary(uniqueKeysWithValues: oldSnapshot.penaltyItems.map { ($0.id, $0) })
        return penaltyItems.flatMap { item -> [AcademicChangeItem] in
            guard let oldItem = oldItemsById[item.id] else {
                return [AcademicChangeItem(signature: "penalty|\(item.id)|created", source: .penalty, subject: item.reason, value: "Новая запись", date: nil, context: "Взыскания и поощрения")]
            }
            if oldItem.status != item.status {
                return [AcademicChangeItem(signature: "penalty|\(item.id)|status|\(item.status)", source: .penalty, subject: item.reason, value: "Статус: \(item.status)", date: nil, context: "Взыскания и поощрения")]
            }
            return []
        }
    }

    private func certificateChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldItemsById = Dictionary(uniqueKeysWithValues: oldSnapshot.certificateItems.map { ($0.id, $0) })
        return certificateItems.flatMap { item -> [AcademicChangeItem] in
            guard let oldItem = oldItemsById[item.id] else {
                return [AcademicChangeItem(signature: "cert|\(item.id)|created", source: .certificate, subject: item.provisionPlace, value: "Заказана", date: nil, context: "Справка")]
            }
            if oldItem.status != item.status {
                let statusText = item.status == 1 ? "Напечатана" : (item.status == 2 ? "Обрабатывается" : "Статус изменен")
                return [AcademicChangeItem(signature: "cert|\(item.id)|status|\(item.status)", source: .certificate, subject: item.provisionPlace, value: statusText, date: nil, context: "Справка")]
            }
            return []
        }
    }

    private func omissionChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldItemsBySubject = Dictionary(uniqueKeysWithValues: oldSnapshot.omissionItems.map { ($0.subject, $0) })

        return omissionItems.compactMap { item in
            let oldHours = oldItemsBySubject[item.subject]?.hours ?? 0
            let delta = item.hours - oldHours
            guard delta > 0 else { return nil }

            return AcademicChangeItem(
                signature: "omission|\(item.subject)|\(item.hours)",
                source: .omission,
                subject: item.subject,
                value: "+\(delta) ч",
                date: nil,
                context: "Неуважительные пропуски"
            )
        }
    }

    private func dormitoryChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldItemsById = Dictionary(uniqueKeysWithValues: oldSnapshot.dormitoryItems.map { ($0.id, $0) })

        return dormitoryItems.flatMap { item -> [AcademicChangeItem] in
            guard let oldItem = oldItemsById[item.id] else {
                return [item.change(field: "created", value: "Появилась новая заявка", context: "Общежитие")]
            }

            return item.changedFields(comparedTo: oldItem).map { field in
                let value = field.newValue == "-" ? "\(field.title): не указано" : "\(field.title): \(field.newValue)"
                return item.change(field: field.key, value: value, context: field.title)
            }
        }
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

    private static func makeOmissionItems(from lessons: [PortalGradeBookLesson]) -> [AcademicOmissionItem] {
        let lessonsBySubject = Dictionary(grouping: lessons) { $0.lessonNameAbbrev }

        return lessonsBySubject.compactMap { subject, subjectLessons in
            let hours = subjectLessons
                .filter { !$0.isRespectfulOmission }
                .reduce(0) { $0 + max($1.gradeBookOmissions, 0) }

            guard hours > 0 else { return nil }
            return AcademicOmissionItem(subject: subject, hours: hours)
        }
        .sorted { $0.subject.localizedCaseInsensitiveCompare($1.subject) == .orderedAscending }
    }

    private static func makeDormitoryItems(from applications: [DormitoryQueueApplication]) -> [DormitoryApplicationItem] {
        applications
            .map(DormitoryApplicationItem.init(application:))
            .sorted { $0.id > $1.id }
    }

    private static func makePenaltyItems(from penalties: [ServiceJSONObject]) -> [PenaltyNotificationItem] {
        penalties.map(PenaltyNotificationItem.init(object:))
    }

    private static func makeCertificateItems(from certificates: [CertificateRequest]) -> [CertificateNotificationItem] {
        certificates.map(CertificateNotificationItem.init(request:))
    }
}

private struct AcademicOmissionItem: Codable, Hashable {
    let subject: String
    let hours: Int
}

private struct DormitoryChangedField {
    let key: String
    let title: String
    let newValue: String
}

private struct DormitoryApplicationItem: Codable, Hashable {
    let id: Int
    let number: Int
    let status: String
    let queueText: String
    let documentText: String
    let acceptedDate: String
    let settledDate: String
    let rejectionReason: String
    let roomInfo: String

    init(application: DormitoryQueueApplication) {
        self.id = application.id
        self.number = application.number
        self.status = application.status
        self.queueText = application.numberInQueue.map { "№\($0)" } ?? "-"
        self.documentText = Self.documentText(for: application)
        self.acceptedDate = Self.formattedDate(application.acceptedDate)
        self.settledDate = Self.formattedDate(application.settledDate)
        self.rejectionReason = Self.normalized(application.rejectionReason)
        self.roomInfo = Self.normalized(application.roomInfo)
    }

    func changedFields(comparedTo oldItem: DormitoryApplicationItem) -> [DormitoryChangedField] {
        [
            oldItem.status == status ? nil : DormitoryChangedField(key: "status", title: "Статус", newValue: status),
            oldItem.queueText == queueText ? nil : DormitoryChangedField(key: "queue", title: "Очередь", newValue: queueText),
            oldItem.documentText == documentText ? nil : DormitoryChangedField(key: "document", title: "Документ", newValue: documentText),
            oldItem.acceptedDate == acceptedDate ? nil : DormitoryChangedField(key: "acceptedDate", title: "Документы приняты", newValue: acceptedDate),
            oldItem.settledDate == settledDate ? nil : DormitoryChangedField(key: "settledDate", title: "Дата заселения", newValue: settledDate),
            oldItem.roomInfo == roomInfo ? nil : DormitoryChangedField(key: "room", title: "Комната", newValue: roomInfo),
            oldItem.rejectionReason == rejectionReason ? nil : DormitoryChangedField(key: "rejectionReason", title: "Причина отклонения", newValue: rejectionReason)
        ].compactMap { $0 }
    }

    func change(field: String, value: String, context: String) -> AcademicChangeItem {
        AcademicChangeItem(
            signature: "dormitory|\(id)|\(field)|\(value)",
            source: .dormitory,
            subject: "Заявка №\(number)",
            value: value,
            date: nil,
            context: context
        )
    }

    private static func documentText(for application: DormitoryQueueApplication) -> String {
        guard application.hasDocument else { return "-" }
        return normalized(application.docReference, fallback: "Документ прикреплён")
    }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return dormitoryNotificationDateFormatter.string(from: date)
    }

    private static func normalized(_ value: String?, fallback: String = "-") -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }
}

private let dormitoryNotificationDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

private struct AcademicChangeItem: Codable, Hashable {
    let signature: String
    let source: AcademicChangeSource
    let subject: String
    let value: String
    let date: String?
    let context: String

    nonisolated static func defaultSort(lhs: AcademicChangeItem, rhs: AcademicChangeItem) -> Bool {
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
    case omission
    case dormitory
    case penalty
    case certificate
}

private struct PenaltyNotificationItem: Codable, Hashable {
    let id: String
    let reason: String
    let status: String
    
    init(object: ServiceJSONObject) {
        self.id = object.stableID
        self.reason = object.fields["reason"]?.scalarText ?? object.primaryText
        self.status = object.fields["status"]?.scalarText ?? ""
    }
}

private struct CertificateNotificationItem: Codable, Hashable {
    let id: Int
    let status: Int
    let provisionPlace: String
    
    init(request: CertificateRequest) {
        self.id = request.id
        self.status = request.status
        self.provisionPlace = request.provisionPlace
    }
}
