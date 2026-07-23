@testable import MyIIS
import XCTest

@MainActor
final class DiplomaApplicationTests: XCTestCase {

    func testDiplomaApplicationSupervisorName() {
        let emp = DiplomaEmployee(
            id: 1,
            firstName: "Иван",
            lastName: "Иванов",
            middleName: "Иванович",
            fio: "Иванов И.И.",
            academicDepartment: nil,
            price: nil
        )
        let app1 = DiplomaApplication(
            id: 1,
            date: nil,
            employee: emp,
            externalManager: nil,
            topic: "Topic",
            belarusianTopic: nil,
            englishTopic: nil,
            justification: nil,
            rejectionReason: nil,
            status: "Pending",
            statusId: 1
        )
        XCTAssertEqual(app1.supervisorName, "Иванов И.И.")
    }

    func testDiplomaApplicationExternalManagerName() {
        let extManager = DiplomaExternalManager(
            id: 2,
            firstName: "Петр",
            lastName: "Петров",
            middleName: "Петрович",
            scienceDegree: nil,
            employeeRank: nil,
            workPlace: nil,
            jobPosition: nil
        )
        let app2 = DiplomaApplication(
            id: 2,
            date: nil,
            employee: nil,
            externalManager: extManager,
            topic: "Topic2",
            belarusianTopic: nil,
            englishTopic: nil,
            justification: nil,
            rejectionReason: nil,
            status: "Pending",
            statusId: 1
        )
        XCTAssertEqual(app2.supervisorName, "Петров Петр Петрович")
    }

    func testDiplomaApplicationMissingSupervisorName() {
        let app3 = DiplomaApplication(
            id: 3,
            date: nil,
            employee: nil,
            externalManager: nil,
            topic: "Topic3",
            belarusianTopic: nil,
            englishTopic: nil,
            justification: nil,
            rejectionReason: nil,
            status: "Pending",
            statusId: 1
        )
        XCTAssertEqual(app3.supervisorName, "Руководитель не указан")
    }

    func testDiplomaApplicationStatuses() {
        let appCancel = DiplomaApplication(
            id: 1,
            date: nil,
            employee: nil,
            externalManager: nil,
            topic: "Topic",
            belarusianTopic: nil,
            englishTopic: nil,
            justification: nil,
            rejectionReason: nil,
            status: "status",
            statusId: 5
        )
        XCTAssertTrue(appCancel.canCancel)
        XCTAssertFalse(appCancel.canDownloadApplication)

        let appDownload = DiplomaApplication(
            id: 2,
            date: nil,
            employee: nil,
            externalManager: nil,
            topic: "Topic",
            belarusianTopic: nil,
            englishTopic: nil,
            justification: nil,
            rejectionReason: nil,
            status: "status",
            statusId: 1
        )
        XCTAssertFalse(appDownload.canCancel)
        XCTAssertTrue(appDownload.canDownloadApplication)
    }

    func testDiplomaEmployeeDisplayName() {
        let emp1 = DiplomaEmployee(
            id: 1,
            firstName: "Алексей",
            lastName: "Смирнов",
            middleName: "Иванович",
            fio: nil,
            academicDepartment: nil,
            price: nil
        )
        XCTAssertEqual(emp1.displayName, "Смирнов Алексей Иванович")

        let emp2 = DiplomaEmployee(id: 2, firstName: nil, lastName: "Смирнов", middleName: nil, fio: "", academicDepartment: nil, price: nil)
        XCTAssertEqual(emp2.displayName, "Смирнов")
    }

    func testDiplomaEmployeeSubtitle() {
        let emp1 = DiplomaEmployee(id: 1, firstName: nil, lastName: nil, middleName: nil, fio: nil, academicDepartment: "Кафедра ПОИТ", price: nil)
        XCTAssertEqual(emp1.subtitle, "Кафедра ПОИТ")

        let emp2 = DiplomaEmployee(id: 2, firstName: nil, lastName: nil, middleName: nil, fio: nil, academicDepartment: "", price: nil)
        XCTAssertNil(emp2.subtitle)
    }

    func testDiplomaExternalManagerSubtitle() {
        let deg = DiplomaNamedValue(id: 1, name: "Кандидат", abbrev: "К.т.н.", price: nil)
        let rank = DiplomaNamedValue(id: 2, name: "Доцент", abbrev: nil, price: nil)
        let ext1 = DiplomaExternalManager(
            id: 1,
            firstName: nil,
            lastName: nil,
            middleName: nil,
            scienceDegree: deg,
            employeeRank: rank,
            workPlace: "БГУИР",
            jobPosition: "Преподаватель"
        )
        XCTAssertEqual(ext1.subtitle, "К.т.н., Доцент, Преподаватель, БГУИР")

        let ext2 = DiplomaExternalManager(
            id: 2,
            firstName: nil,
            lastName: nil,
            middleName: nil,
            scienceDegree: nil,
            employeeRank: nil,
            workPlace: "",
            jobPosition: nil
        )
        XCTAssertNil(ext2.subtitle)
    }

    func testDiplomaNamedValueDisplayName() {
        let nv1 = DiplomaNamedValue(id: 1, name: "Full Name", abbrev: "FN", price: nil)
        XCTAssertEqual(nv1.displayName, "FN")

        let nv2 = DiplomaNamedValue(id: 2, name: "Full Name", abbrev: "", price: nil)
        XCTAssertEqual(nv2.displayName, "Full Name")

        let nv3 = DiplomaNamedValue(id: 3, name: nil, abbrev: nil, price: nil)
        XCTAssertNil(nv3.displayName)
    }

    func testDiplomaSupervisor() {
        let emp = DiplomaEmployee(id: 1, firstName: "A", lastName: "B", middleName: "C", fio: nil, academicDepartment: "Dep1", price: nil)
        let supEmp = DiplomaSupervisor.employee(emp)
        XCTAssertEqual(supEmp.id, "employee-1")
        XCTAssertEqual(supEmp.title, "B A C")
        XCTAssertEqual(supEmp.subtitle, "Dep1")
        XCTAssertEqual(supEmp.employeeId, 1)
        XCTAssertNil(supEmp.externalManagerId)
        XCTAssertFalse(supEmp.isExternal)

        let ext = DiplomaExternalManager(
            id: 2,
            firstName: "X",
            lastName: "Y",
            middleName: "Z",
            scienceDegree: nil,
            employeeRank: nil,
            workPlace: nil,
            jobPosition: nil
        )
        let supExt = DiplomaSupervisor.external(ext)
        XCTAssertEqual(supExt.id, "external-2")
        XCTAssertEqual(supExt.title, "Y X Z")
        XCTAssertNil(supExt.subtitle)
        XCTAssertEqual(supExt.externalManagerId, 2)
        XCTAssertNil(supExt.employeeId)
        XCTAssertTrue(supExt.isExternal)
    }
}
