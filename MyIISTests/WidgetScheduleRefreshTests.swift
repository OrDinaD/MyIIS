import Foundation
@testable import MyIIS
import XCTest

@MainActor
final class WidgetScheduleRefreshTests: XCTestCase {
    func testTeacherRefreshUsesIdentifierInsteadOfExactDisplayName() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("teacher-a", forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("Иванов И.И.", forKey: WidgetScheduleSelection.teacherNameKey)
        let session = makeSession()
        defer { session.invalidateAndCancel(); MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data("""
            {"employeeDto":{"id":1,"urlId":"teacher-a","lastName":"Иванов","firstName":"Иван","middleName":"Иванович"},"schedules":{}}
            """.utf8))
        }
        var published: [String] = []
        let service = WidgetScheduleRefreshService(
            api: makeAPI(session: session, defaults: defaults), defaults: defaults,
            publish: { schedule, exams in published = [schedule.groupName, exams.groupName] }
        )
        await service.refresh(force: true)
        XCTAssertEqual(published, ["Иванов И.И.", "Иванов И.И."])
    }

    func testLateResponseCannotPublishAfterTeacherWithSameNameIsSelected() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("teacher-a", forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("Иванов И.И.", forKey: WidgetScheduleSelection.teacherNameKey)
        let session = makeSession()
        let releaseResponse = DispatchSemaphore(value: 0)
        defer {
            releaseResponse.signal()
            session.invalidateAndCancel()
            MockURLProtocol.requestHandler = nil
        }
        let requested = expectation(description: "Old teacher request started")
        MockURLProtocol.requestHandler = { request in
            requested.fulfill()
            _ = releaseResponse.wait(timeout: .now() + 5)
            let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data("""
            {"employeeDto":{"id":1,"urlId":"teacher-a","lastName":"Иванов","firstName":"Иван","middleName":"Иванович"},"schedules":{}}
            """.utf8))
        }
        var publishCount = 0
        let service = WidgetScheduleRefreshService(
            api: makeAPI(session: session, defaults: defaults), defaults: defaults,
            publish: { _, _ in publishCount += 1 }
        )
        let task = Task { await service.refresh(force: true) }
        await fulfillment(of: [requested], timeout: 2)
        defaults.set("teacher-b", forKey: WidgetScheduleSelection.teacherIDKey)
        releaseResponse.signal()
        await task.value
        XCTAssertEqual(publishCount, 0)
    }

    func testReturningToGroupFetchesItEvenAfterTeacherRefresh() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("420603", forKey: WidgetScheduleSelection.accountGroupKey)
        defaults.set("teacher-a", forKey: WidgetScheduleSelection.teacherIDKey)
        defaults.set("Иванов И.И.", forKey: WidgetScheduleSelection.teacherNameKey)
        let session = makeSession()
        defer { session.invalidateAndCancel(); MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            let payload = url.path.contains("employees")
                ? """
                {"employeeDto":{"id":1,"urlId":"teacher-a","lastName":"Иванов"},"schedules":{}}
                """
                : """
                {"studentGroupDto":{"name":"420603"},"schedules":{}}
                """
            return (response, Data(payload.utf8))
        }
        var published: [String] = []
        let service = WidgetScheduleRefreshService(
            api: makeAPI(session: session, defaults: defaults), defaults: defaults,
            publish: { schedule, _ in published.append(schedule.groupName) }
        )
        await service.refresh(force: true)
        WidgetScheduleSelection.useAccountGroup(in: defaults)
        await service.refresh(force: true)
        XCTAssertEqual(published, ["Иванов И.И.", "420603"])
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "WidgetScheduleRefreshTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeAPI(session: URLSession, defaults: UserDefaults) -> ServiceEndpointsAPI {
        ServiceEndpointsAPI(
            baseURL: URLFactory.require("https://widget-tests.example/api/v1"),
            session: session, userDefaults: defaults
        )
    }
}
