import Foundation

#if DEBUG
extension StudyPlan {
    static let mock: StudyPlan = {
        let formatter = StudyPlanDateParser.shared
        let start = formatter.date(from: "01.09.2025")
        let end = formatter.date(from: "28.12.2025")
        let examsStart = formatter.date(from: "29.12.2025")
        let examsEnd = formatter.date(from: "25.01.2026")

        let teacher = DisciplineEmployee(
            id: 1,
            firstName: "Андрей",
            middleName: "Константинович",
            lastName: "Ючков",
            photoLink: nil,
            degree: nil,
            degreeAbbrev: nil,
            rank: nil,
            email: nil,
            urlId: nil,
            calendarId: nil,
            jobPositions: nil,
            isChief: nil
        )

        let oop = DisciplineSchedule(
            id: UUID().uuidString,
            auditories: ["605-5 к."],
            endLessonTime: "11:30",
            lessonTypeAbbrev: "ЛР",
            note: nil,
            subgroup: 0,
            startLessonTime: "10:05",
            studentGroups: [],
            subject: "ООП",
            subjectFullName: "Объектно-ориентированное программирование",
            weekNumbers: [1, 3],
            employees: [teacher],
            lessonDate: nil,
            startLessonDate: formatter.date(from: "06.09.2025"),
            endLessonDate: formatter.date(from: "27.12.2025"),
            isAnnouncement: false,
            isSplit: false
        )

        let graphs = DisciplineSchedule(
            id: UUID().uuidString,
            auditories: ["601б-5 к."],
            endLessonTime: "09:55",
            lessonTypeAbbrev: "ПЗ",
            note: nil,
            subgroup: 0,
            startLessonTime: "08:30",
            studentGroups: [],
            subject: "ТГ",
            subjectFullName: "Теория графов",
            weekNumbers: [1, 3],
            employees: [teacher],
            lessonDate: nil,
            startLessonDate: formatter.date(from: "06.09.2025"),
            endLessonDate: formatter.date(from: "27.12.2025"),
            isAnnouncement: false,
            isSplit: false
        )

        let schedule: [StudyWeekday: [DisciplineSchedule]] = [
            .saturday: [graphs, oop]
        ]

        return StudyPlan(
            startDate: start,
            endDate: end,
            startExamsDate: examsStart,
            endExamsDate: examsEnd,
            group: StudyGroup(
                name: "420603",
                facultyId: 20005,
                facultyAbbrev: "ФИТУ",
                facultyName: "Факультет информационных технологий и управления",
                specialityDepartmentEducationFormId: 20835,
                specialityName: "Системы управления информацией",
                specialityAbbrev: "СУИ (АСОИ)",
                course: 2,
                id: 24930,
                calendarId: nil,
                educationDegree: 1
            ),
            schedule: schedule
        )
    }()
}
#endif
