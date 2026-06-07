import Foundation
import UserNotifications

final class ExamReminderNotificationService {
    static let shared = ExamReminderNotificationService()

    private let notificationCenter: UNUserNotificationCenter
    private let calendar: Calendar

    private init(
        notificationCenter: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    @discardableResult
    func scheduleIfAuthorized(exams: [DisciplineSchedule], groupName: String) async -> Int {
        let settings = await notificationCenter.notificationSettings()
        guard Self.isAuthorized(settings.authorizationStatus) else { return 0 }
        return await schedule(exams: exams, groupName: groupName)
    }

    @discardableResult
    func scheduleFromUserAction(exams: [DisciplineSchedule], groupName: String) async -> Int {
        guard await requestAuthorizationIfNeeded() else { return 0 }
        return await schedule(exams: exams, groupName: groupName)
    }

    private func schedule(exams: [DisciplineSchedule], groupName: String) async -> Int {
        let prefix = identifierPrefix(for: groupName)
        let pending = await notificationCenter.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: pending)

        let examItems = exams
            .filter(\.isExamReminderEligible)
            .compactMap { exam -> (exam: DisciplineSchedule, reminderDate: Date)? in
                guard let reminderDate = reminderDate(for: exam) else { return nil }
                return (exam, reminderDate)
            }
            .sorted { lhs, rhs in lhs.reminderDate < rhs.reminderDate }

        var scheduledCount = 0
        for item in examItems {
            let content = UNMutableNotificationContent()
            content.title = "Завтра важный день"
            content.body = notificationBody(for: item.exam)
            content.sound = .default
            content.threadIdentifier = "exam-reminders"
            content.categoryIdentifier = "exam-reminders"

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(prefix)\(item.exam.id.hashValue)",
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                scheduledCount += 1
            } catch {
                LogService.shared.log("⚠️ Failed to schedule exam reminder: \(error.localizedDescription)")
            }
        }

        return scheduledCount
    }

    private func reminderDate(for exam: DisciplineSchedule) -> Date? {
        guard let examDate = exam.lessonDate ?? exam.startLessonDate else { return nil }
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: examDate) else { return nil }
        let reminderDate = calendar.date(bySettingHour: 19, minute: 30, second: 0, of: previousDay)
        guard let reminderDate, reminderDate > Date() else { return nil }
        return reminderDate
    }

    private func notificationBody(for exam: DisciplineSchedule) -> String {
        let subject = exam.title.replacingOccurrences(of: "📣 ", with: "")
        var details: [String] = []

        if !exam.timeRange.isEmpty {
            details.append(exam.timeRange)
        }
        if !exam.location.isEmpty {
            details.append(exam.location)
        }

        let suffix = details.isEmpty ? "Проверь время и аудиторию в расписании." : "\(details.joined(separator: ", "))."
        return "Вижу, у тебя завтра \(subject). Выдохни, собери всё нужное и ложись пораньше. \(suffix) Удачи — ты справишься."
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                LogService.shared.log("⚠️ Exam reminder authorization failed: \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func identifierPrefix(for groupName: String) -> String {
        "exam-reminder-\(groupName)-"
    }

    private static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}

private extension DisciplineSchedule {
    var isExamReminderEligible: Bool {
        lessonTypeAbbrev.localizedCaseInsensitiveContains("экзам")
    }
}
