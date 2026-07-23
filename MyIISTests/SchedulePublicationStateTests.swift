@testable import MyIIS
import XCTest

@MainActor
final class SchedulePublicationStateTests: XCTestCase {
    func testScheduleFormationResponseBecomesPublicationPendingState() {
        let error = APIError.serverError(
            statusCode: 503,
            message: "На данный момент расписание недоступно, идёт формирование на следующий семестр."
        )

        XCTAssertTrue(ScheduleServiceViewModel.isPublicationPendingError(error))
        XCTAssertTrue(PublicScheduleResponse.publicationPending.isSchedulePublicationPending())
    }

    func testUnrelatedServiceUnavailableResponseRemainsAnError() {
        let error = APIError.serverError(statusCode: 503, message: "Сервис временно недоступен")

        XCTAssertFalse(ScheduleServiceViewModel.isPublicationPendingError(error))
    }
}
