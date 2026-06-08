import Foundation

struct DemoMockData {
    static let loginResponse = LoginResponse(
        username: "demo",
        fio: "Алексеев Максим Дмитриевич",
        email: "m.alekseev@bsuir.by",
        authorities: ["ROLE_STUDENT"],
        accountType: "STUDENT",
        phone: "+375 29 123-45-67",
        group: "220603",
        photoUrl: "http://127.0.0.1:8123/avatar.jpg",
        isGroupHead: true,
        canStudentNote: true,
        hasNotConfirmedContact: false,
        hasProfiling: false
    )

    static let personalProfile = PersonalProfile(
        firstName: "Максим",
        lastName: "Алексеев",
        middleName: "Дмитриевич",
        belarusianFirstName: "Максім",
        belarusianLastName: "Аляксееў",
        belarusianMiddleName: "Дзмітрыевіч",
        birthDate: "12.04.2004",
        photoUrl: "http://127.0.0.1:8123/avatar.jpg",
        course: 3,
        faculty: "ФИТУ",
        speciality: "СУИ",
        studentGroup: "220603",
        rating: 95
    )

    static let scheduleInfo = ScheduleInfo(
        facultyAbbrev: "ФИТУ",
        facultyName: "Факультет информационных технологий и управления",
        specialityAbbrev: "СУИ",
        specialityName: "Системы управления информацией",
        course: 3,
        specialityDepartmentEducationFormId: 20835,
        studentGroupId: 24930,
        educationDegree: 1
    )

    static let userGroupInfo: UserGroupInfoResponse = {
        let jsonString = """
        {
            "numberOfGroup": "220603",
            "studentGroupCuratorDto": {
                "position": "Куратор",
                "fio": "Егорова А.И."
            },
            "groupInfoStudentDto": [
                {
                    "position": "Староста",
                    "fio": "Алексеев Максим Дмитриевич"
                },
                {
                    "position": "Студент",
                    "fio": "Павлов Дмитрий Александрович"
                },
                {
                    "position": "Студент",
                    "fio": "Смирнова Екатерина Игоревна"
                }
            ]
        }
        """
        let json = Data(jsonString.utf8)
        do {
            return try JSONDecoder().decode(UserGroupInfoResponse.self, from: json)
        } catch {
            fatalError("Failed to decode DemoMockData.userGroupInfo: \(error)")
        }
    }()

    static let markbookResponse = MarkbookResponse(
        number: "22060301",
        averageMark: 9.3,
        markPages: [
            "5": MarkbookSemester(
                averageMark: 9.4,
                marks: [
                    MarkbookMark(
                        subject: "Математика",
                        formOfControl: "Экзамен",
                        fullSubject: "Специальные главы математики",
                        hours: "120",
                        credits: 4.0,
                        mark: "10",
                        date: "15.01.2025",
                        teacher: "Сидоров С.С.",
                        commonMark: nil,
                        commonRetakes: nil,
                        retakesCount: 0
                    ),
                    MarkbookMark(
                        subject: "ОАиП",
                        formOfControl: "Экзамен",
                        fullSubject: "Основы алгоритмизации и программирования",
                        hours: "140",
                        credits: 5.0,
                        mark: "9",
                        date: "20.01.2025",
                        teacher: "Белов Б.Б.",
                        commonMark: nil,
                        commonRetakes: nil,
                        retakesCount: 0
                    )
                ]
            )
        ]
    )

    static let portalGradeBookLessons: [PortalGradeBookLesson] = [
        PortalGradeBookLesson(
            id: 1,
            dateString: "01.09.2025",
            gradeBookOmissions: 0,
            isRespectfulOmission: false,
            lessonTypeId: 1,
            lessonTypeAbbrev: "ЛК",
            lessonNameAbbrev: "Машинное обучение",
            subGroup: 0,
            marks: [10],
            controlPoint: "КТ 1"
        ),
        PortalGradeBookLesson(
            id: 2,
            dateString: "02.09.2025",
            gradeBookOmissions: 0,
            isRespectfulOmission: false,
            lessonTypeId: 2,
            lessonTypeAbbrev: "ПЗ",
            lessonNameAbbrev: "Мобильная разработка",
            subGroup: 1,
            marks: [9, 10],
            controlPoint: "КТ 1"
        ),
        PortalGradeBookLesson(
            id: 3,
            dateString: "10.09.2025",
            gradeBookOmissions: 0,
            isRespectfulOmission: false,
            lessonTypeId: 3,
            lessonTypeAbbrev: "ЛР",
            lessonNameAbbrev: "Базы данных",
            subGroup: 2,
            marks: [10],
            controlPoint: "КТ 2"
        ),
        PortalGradeBookLesson(
            id: 4,
            dateString: "15.09.2025",
            gradeBookOmissions: 0,
            isRespectfulOmission: false,
            lessonTypeId: 1,
            lessonTypeAbbrev: "ЛК",
            lessonNameAbbrev: "Базы данных",
            subGroup: 2,
            marks: [9],
            controlPoint: "КТ 2"
        )
    ]

    static let gradebook = Gradebook(
        semesters: [
            GradebookSemester(
                number: 6,
                title: "6 семестр",
                year: "2024/2025",
                disciplines: [
                    GradebookDiscipline(
                        code: "AI401",
                        name: "Машинное обучение",
                        controlForm: "Курсовой проект",
                        teacher: "Борисова А.А.",
                        hours: 108,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "COURSEWORK", grade: .numeric(10), date: "2025-05-10", status: .passed)
                        ],
                        lessonOmissions: nil
                    ),
                    GradebookDiscipline(
                        code: "IOSDEV",
                        name: "Мобильная разработка",
                        controlForm: "Экзамен",
                        teacher: "Смирнов А.В.",
                        hours: 120,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(10), date: "2025-06-20", status: .passed)
                        ],
                        lessonOmissions: nil
                    ),
                    GradebookDiscipline(
                        code: "NET301",
                        name: "Компьютерные сети",
                        controlForm: "Экзамен",
                        teacher: "Петров П.П.",
                        hours: 144,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(9), date: "2025-06-25", status: .passed)
                        ],
                        lessonOmissions: nil
                    )
                ]
            ),
            GradebookSemester(
                number: 5,
                title: "5 семестр",
                year: "2023/2024",
                disciplines: [
                    GradebookDiscipline(
                        code: "ALG101",
                        name: "Базы данных",
                        controlForm: "Экзамен",
                        teacher: "Иванов И.И.",
                        hours: 144,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "EXAM", grade: .numeric(9), date: "2024-01-15", status: .passed)
                        ],
                        lessonOmissions: nil
                    ),
                    GradebookDiscipline(
                        code: "HIST202",
                        name: "Основы права",
                        controlForm: "Зачёт",
                        teacher: "Сидорова С.С.",
                        hours: 72,
                        attempts: [
                            GradeAttempt(attempt: 1, type: "CREDIT", grade: .textual("зачёт"), date: "2024-01-10", status: .passed)
                        ],
                        lessonOmissions: nil
                    )
                ]
            )
        ]
    ).normalized()

    static let rating: [StudentRating] = [
        StudentRating(
            recordBookNumber: "22060301",
            studentName: "Алексеев Максим Дмитриевич",
            averageGrade: 9.35,
            missedHours: 0,
            averageShift: 0.1,
            checkpoints: [
                RatingCheckpoint(number: 1, averageGrade: 9.4, missedHours: 0),
                RatingCheckpoint(number: 2, averageGrade: 9.3, missedHours: 0),
                RatingCheckpoint(number: 3, averageGrade: 9.5, missedHours: 0)
            ]
        ),
        StudentRating(
            recordBookNumber: "22060302",
            studentName: "Павлов Дмитрий Александрович",
            averageGrade: 8.4,
            missedHours: 4,
            averageShift: -0.2,
            checkpoints: [
                RatingCheckpoint(number: 1, averageGrade: 8.6, missedHours: 2),
                RatingCheckpoint(number: 2, averageGrade: 8.2, missedHours: 2),
                RatingCheckpoint(number: 3, averageGrade: 8.4, missedHours: 0)
            ]
        ),
        StudentRating(
            recordBookNumber: "22060303",
            studentName: "Смирнова Екатерина Игоревна",
            averageGrade: 9.1,
            missedHours: 2,
            averageShift: 0.3,
            checkpoints: [
                RatingCheckpoint(number: 1, averageGrade: 8.8, missedHours: 2),
                RatingCheckpoint(number: 2, averageGrade: 9.2, missedHours: 0),
                RatingCheckpoint(number: 3, averageGrade: 9.3, missedHours: 0)
            ]
        )
    ]

    #if DEBUG
    static let studyPlan = StudyPlan.mock
    #else
    static let studyPlan: StudyPlan = {
        let formatter = StudyPlanDateParser.shared
        let start = formatter.date(from: "01.09.2025")
        let end = formatter.date(from: "28.12.2025")
        return StudyPlan(
            startDate: start,
            endDate: end,
            startExamsDate: start,
            endExamsDate: end,
            group: StudyGroup(
                name: "220603",
                facultyId: 20005,
                facultyAbbrev: "ФКСиС",
                facultyName: "ФКСиС",
                specialityDepartmentEducationFormId: 20835,
                specialityName: "ПОИТ",
                specialityAbbrev: "ПОИТ",
                course: 3,
                id: 24930,
                calendarId: nil,
                educationDegree: 1
            ),
            schedule: [:]
        )
    }()
    #endif
}
