import Foundation

/// GET /api/v1/personal-rating. Contract captured from IIS on 2026-09-26.
struct PersonalRatingResponse: Decodable, Sendable {
    let subjects: [PersonalRatingSubject]
    let deadlines: [PersonalRatingDeadlineGroup]
    let percentageMarks: [RatingPercentageMark]

    var lessons: [RatingLesson] {
        subjects.flatMap { subject in
            subject.lessonTypes.flatMap { type in
                type.lessons.map { lesson in
                    RatingLesson(
                        id: lesson.id, dateString: lesson.dateString,
                        gradeBookOmissions: lesson.gradebookOmissions, isRespectfulOmission: false,
                        lessonTypeId: type.id, lessonTypeAbbrev: type.abbrev,
                        lessonNameAbbrev: subject.abbrev, lessonName: subject.name,
                        subGroup: lesson.subGroup,
                        marks: lesson.marks.compactMap(\.mark),
                        markDetails: lesson.marks.compactMap { mark in
                            mark.mark.map { RatingLessonMark(mark: $0, taskNumber: mark.taskNumber) }
                        },
                        controlPoint: lesson.controlPoint
                    )
                }
            }
        }
    }

    init(subjects: [PersonalRatingSubject], deadlines: [PersonalRatingDeadlineGroup], percentageMarks: [RatingPercentageMark]) {
        self.subjects = subjects
        self.deadlines = deadlines
        self.percentageMarks = percentageMarks
    }

    /// Builds in-memory demo/test data; network decoding always requires the nested subjects contract.
    init(lessons: [RatingLesson]) {
        subjects = Dictionary(grouping: lessons, by: \.lessonNameAbbrev)
            .sorted { $0.key < $1.key }
            .enumerated().map { index, entry in
                PersonalRatingSubject(
                    id: index + 1, abbrev: entry.key, name: entry.value.first?.lessonName ?? entry.key,
                    lessonTypes: Dictionary(grouping: entry.value, by: \.lessonTypeId)
                        .sorted { $0.key < $1.key }.map { typeID, lessons in
                            PersonalRatingLessonType(
                                id: typeID, abbrev: lessons.first?.lessonTypeAbbrev ?? "",
                                termHoursId: typeID,
                                lessons: lessons.map {
                                    PersonalRatingLesson(
                                        id: $0.id, dateString: $0.dateString,
                                        gradebookOmissions: $0.gradeBookOmissions, subGroup: $0.subGroup,
                                        marks: $0.markDetails.map { PersonalRatingMark(mark: $0.mark, taskNumber: $0.taskNumber) },
                                        controlPoint: $0.controlPoint
                                    )
                                }
                            )
                        }
                )
            }
        deadlines = []
        percentageMarks = []
    }
}

struct PersonalRatingSubject: Decodable, Sendable {
    let id: Int
    let abbrev: String
    let name: String
    let lessonTypes: [PersonalRatingLessonType]
}

struct PersonalRatingLessonType: Decodable, Sendable {
    let id: Int
    let abbrev: String
    let termHoursId: Int
    let lessons: [PersonalRatingLesson]
}

struct PersonalRatingLesson: Decodable, Sendable {
    let id: Int
    let dateString: String
    let gradebookOmissions: Int
    let subGroup: Int
    let marks: [PersonalRatingMark]
    let controlPoint: String
}

struct PersonalRatingMark: Decodable, Sendable {
    let mark: Int?
    let taskNumber: Int?
}

struct PersonalRatingDeadlineGroup: Decodable, Sendable {
    let termHoursId: Int
    let taskCount: Int?
    let deadlines: [PersonalRatingDeadline]
}

struct PersonalRatingDeadline: Decodable, Sendable {
    let lessonId: Int
    let taskNumber: Int?
}
