@testable import MyIIS
import UIKit
import XCTest

@MainActor
final class AttendanceAndTeacherRegressionTests: XCTestCase {
    func testAllPeriodPayloadKeepsTermsAndDuplicateRows() throws {
        let payload = """
        [
          {"date":"2025-01-17","subject":{"id":1,"name":"Математика","abbrev":"М"},"lessonTypeAbbrev":"ЛК","hours":2,"term":2},
          {"date":"2025-09-17","subject":{"id":2,"name":"Физика","abbrev":"Ф"},"lessonTypeAbbrev":"ЛР","hours":2,"term":3},
          {"date":"2025-09-17","subject":{"id":2,"name":"Физика","abbrev":"Ф"},"lessonTypeAbbrev":"ЛР","hours":2,"term":3}
        ]
        """
        let omissions = try JSONDecoder().decode([DisrespectfulOmission].self, from: Data(payload.utf8))
        let semesters = AttendanceSemester.group(omissions)
        XCTAssertEqual(semesters.map(\.id), [3, 2])
        XCTAssertEqual(semesters.map(\.hours), [4, 2])
        XCTAssertEqual(Set(semesters[0].records.map(\.id)).count, 2)
        XCTAssertTrue(AttendanceSemester.group([]).isEmpty)
    }

    func testTeacherInitialsUseLatinGivenNameAndPatronymic() {
        XCTAssertEqual(TeacherInitials.make(firstName: "Диана", middleName: "Владимировна", lastName: "Концева", languageCode: "en"), "DV")
        XCTAssertEqual(TeacherInitials.make(firstName: "  Анна ", middleName: nil, lastName: "Иванова", languageCode: "en"), "A")
        XCTAssertEqual(TeacherInitials.make(firstName: nil, middleName: nil, lastName: "Концева", languageCode: "en"), "K")
        XCTAssertEqual(TeacherInitials.make(firstName: " ", middleName: nil, lastName: nil, languageCode: "en"), "?")
    }

    func testBlankTeacherPhotoDetectionAndDownsampling() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 350, height: 350))
        let white = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 350, height: 350))
        }
        let portrait = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 350, height: 350))
            UIColor.black.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 150, height: 150))
        }
        XCTAssertTrue(TeacherPhotoValidation.isBlank(white.cgImage))
        XCTAssertFalse(TeacherPhotoValidation.isBlank(portrait.cgImage))
        let data = try XCTUnwrap(portrait.pngData())
        let thumbnail = try XCTUnwrap(ImageDownsampler.image(from: data, maxPixelSize: 64))
        XCTAssertLessThanOrEqual(try XCTUnwrap(thumbnail.cgImage).width, 64)
        XCTAssertNil(ImageDownsampler.image(from: Data(), maxPixelSize: 64))
    }

    func testLecturerSurnameMappingExcludesLaboratoryTeachers() throws {
        let json = """
        {"schedules":{"Понедельник":[
          {"subject":"Ф","lessonTypeAbbrev":"ЛК","employees":[{"id":1,"lastName":"Иванов"}]},
          {"subject":"Ф","lessonTypeAbbrev":"ЛР","employees":[{"id":2,"lastName":"Петров"}]},
          {"subject":"Ф","lessonTypeAbbrev":"ЛК","employees":[{"id":3,"lastName":"Сидоров"}]},
          {"subject":"М","lessonTypeAbbrev":"ЛР","employees":[{"id":4,"lastName":"Орлов"}]}
        ]}}
        """
        let schedule = try JSONDecoder().decode(PublicScheduleResponse.self, from: Data(json.utf8))
        let lecturers = LecturerSurnames.group(schedule.orderedDays.flatMap(\.lessons))
        XCTAssertEqual(lecturers["ф"], "Иванов, Сидоров")
        XCTAssertNil(lecturers["м"])
    }
}
