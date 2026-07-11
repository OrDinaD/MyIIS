import Foundation

struct AcademicChangeSnapshot: Codable, Equatable {
    let markbookItems: [AcademicChangeItem]
    let ratingItems: [AcademicChangeItem]
    let omissionItems: [AcademicOmissionItem]
    let dormitoryItems: [DormitoryApplicationItem]
    let penaltyItems: [PenaltyNotificationItem]
    let certificateItems: [CertificateNotificationItem]
    let scheduleItems: [AcademicChangeItem]
    let hasDormitoryBaseline: Bool
    let hasPenaltiesBaseline: Bool
    let hasCertificatesBaseline: Bool
    let hasScheduleBaseline: Bool
    let capturedAt: Date

    private enum CodingKeys: String, CodingKey {
        case markbookItems
        case ratingItems
        case omissionItems
        case dormitoryItems
        case penaltyItems
        case certificateItems
        case scheduleItems
        case hasDormitoryBaseline
        case hasPenaltiesBaseline
        case hasCertificatesBaseline
        case hasScheduleBaseline
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
        self.scheduleItems = try container.decodeIfPresent([AcademicChangeItem].self, forKey: .scheduleItems) ?? []
        self.hasDormitoryBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasDormitoryBaseline) ?? false
        self.hasPenaltiesBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasPenaltiesBaseline) ?? false
        self.hasCertificatesBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasCertificatesBaseline) ?? false
        self.hasScheduleBaseline = try container.decodeIfPresent(Bool.self, forKey: .hasScheduleBaseline) ?? false
        self.capturedAt = try container.decode(Date.self, forKey: .capturedAt)
    }

    init(
        markbook: MarkbookResponse,
        ratingLessons: [PortalGradeBookLesson],
        dormitoryApplications: [DormitoryQueueApplication]?,
        penalties: [ServiceJSONObject]?,
        certificates: [CertificateRequest]?,
        studyPlan: StudyPlan?,
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

        if let studyPlan {
            self.scheduleItems = Self.makeScheduleItems(from: studyPlan)
            self.hasScheduleBaseline = true
        } else {
            self.scheduleItems = previousSnapshot?.scheduleItems ?? []
            self.hasScheduleBaseline = previousSnapshot?.hasScheduleBaseline == true
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

        let scheduleChanges = hasScheduleBaseline && oldSnapshot.hasScheduleBaseline
            ? scheduleChanges(since: oldSnapshot)
            : []

        return (gradeChanges + omissionChanges(since: oldSnapshot) + dormitoryChanges + penChanges + certChanges + scheduleChanges)
            .sorted(by: AcademicChangeItem.defaultSort)
    }

    private func scheduleChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        if oldSnapshot.scheduleItems.isEmpty, !scheduleItems.isEmpty {
            let firstSignature = scheduleItems.first?.signature ?? "schedule"
            return [AcademicChangeItem(
                signature: "schedule|appeared|\(scheduleItems.count)|\(firstSignature)",
                source: .schedule,
                subject: "Расписание группы",
                value: "Появилось новое расписание",
                date: nil,
                context: "Расписание"
            )]
        }

        let oldSignatures = Set(oldSnapshot.scheduleItems.map(\.signature))
        return scheduleItems.filter { item in !oldSignatures.contains(item.signature) }
    }

    private func penaltyChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldItemsById = Dictionary(uniqueKeysWithValues: oldSnapshot.penaltyItems.map { ($0.id, $0) })
        return penaltyItems.flatMap { item -> [AcademicChangeItem] in
            guard let oldItem = oldItemsById[item.id] else {
                return [AcademicChangeItem(
                    signature: "penalty|\(item.id)|created",
                    source: .penalty,
                    subject: item.reason,
                    value: "Новая запись",
                    date: nil,
                    context: "Взыскания и поощрения"
                )]
            }
            if oldItem.status != item.status {
                return [AcademicChangeItem(
                    signature: "penalty|\(item.id)|status|\(item.status)",
                    source: .penalty,
                    subject: item.reason,
                    value: "Статус: \(item.status)",
                    date: nil,
                    context: "Взыскания и поощрения"
                )]
            }
            return []
        }
    }

    private func certificateChanges(since oldSnapshot: AcademicChangeSnapshot) -> [AcademicChangeItem] {
        let oldItemsById = Dictionary(uniqueKeysWithValues: oldSnapshot.certificateItems.map { ($0.id, $0) })
        return certificateItems.flatMap { item -> [AcademicChangeItem] in
            guard let oldItem = oldItemsById[item.id] else {
                return [AcademicChangeItem(
                    signature: "cert|\(item.id)|created",
                    source: .certificate,
                    subject: item.provisionPlace,
                    value: "Заказана",
                    date: nil,
                    context: "Справка"
                )]
            }
            if oldItem.status != item.status {
                let statusText = item.status == 1
                    ? "Напечатана"
                    : (item.status == 2 ? "Обрабатывается" : "Статус изменен")
                return [AcademicChangeItem(
                    signature: "cert|\(item.id)|status|\(item.status)",
                    source: .certificate,
                    subject: item.provisionPlace,
                    value: statusText,
                    date: nil,
                    context: "Справка"
                )]
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

}

extension AcademicChangeSnapshot {
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

    private static func makeScheduleItems(from plan: StudyPlan) -> [AcademicChangeItem] {
        var items = [AcademicChangeItem]()
        let disciplineTitles = plan.uniqueDisciplines().map(\.title)

        if !disciplineTitles.isEmpty {
            let visibleTitles = disciplineTitles.prefix(3).joined(separator: ", ")
            let remainingCount = disciplineTitles.count - min(disciplineTitles.count, 3)
            let suffix = remainingCount > 0 ? " и еще \(remainingCount)" : ""
            items.append(AcademicChangeItem(
                signature: "schedule|lessons|\(disciplineTitles.joined(separator: "|"))",
                source: .schedule,
                subject: "Расписание занятий",
                value: "Появились пары: \(visibleTitles)\(suffix)",
                date: nil,
                context: "Расписание"
            ))
        }

        if let startDate = plan.startDate {
            items.append(AcademicChangeItem(
                signature: "schedule|semester|\(startDate.timeIntervalSince1970)",
                source: .schedule,
                subject: "Расписание занятий",
                value: "Добавлено на новый семестр",
                date: nil,
                context: "Расписание"
            ))
        }
        if let startExamsDate = plan.startExamsDate {
            items.append(AcademicChangeItem(
                signature: "schedule|exams|\(startExamsDate.timeIntervalSince1970)",
                source: .schedule,
                subject: "Расписание экзаменов",
                value: "Добавлена новая сессия",
                date: nil,
                context: "Расписание"
            ))
        }
        return items
    }
}

struct AcademicOmissionItem: Codable, Hashable {
    let subject: String
    let hours: Int
}

struct DormitoryChangedField {
    let key: String
    let title: String
    let newValue: String
}

struct DormitoryApplicationItem: Codable, Hashable {
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

struct AcademicChangeItem: Codable, Hashable {
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

enum AcademicChangeSource: String, Codable {
    case markbook
    case rating
    case omission
    case dormitory
    case penalty
    case certificate
    case schedule
}

struct PenaltyNotificationItem: Codable, Hashable {
    let id: String
    let reason: String
    let status: String

    init(object: ServiceJSONObject) {
        self.id = object.stableID
        self.reason = object.fields["reason"]?.scalarText ?? object.primaryText
        self.status = object.fields["status"]?.scalarText ?? ""
    }
}

struct CertificateNotificationItem: Codable, Hashable {
    let id: Int
    let status: Int
    let provisionPlace: String

    init(request: CertificateRequest) {
        self.id = request.id
        self.status = request.status
        self.provisionPlace = request.provisionPlace
    }
}
