import XCTest
@testable import MyIIS

@MainActor
final class AttendanceViewModelTests: XCTestCase {
    func testLoadDataPopulatesAndSortsResponses() async {
        let baseDate = Date()
        let mockService = AttendanceAPIServiceMock(
            applicationsResult: .success([
                OmissionApplication(
                    id: 1,
                    status: "APPROVED",
                    number: 100,
                    createdDate: baseDate.addingTimeInterval(-5),
                    rejectionReason: nil,
                    omissionCertificateType: "ОРВИ",
                    dateFrom: baseDate.addingTimeInterval(-10_000),
                    dateTo: baseDate.addingTimeInterval(-9_000),
                    placeOfStay: nil,
                    signature: nil
                ),
                OmissionApplication(
                    id: 2,
                    status: "PENDING",
                    number: 101,
                    createdDate: baseDate,
                    rejectionReason: nil,
                    omissionCertificateType: "ОРВИ",
                    dateFrom: baseDate.addingTimeInterval(-8_000),
                    dateTo: baseDate.addingTimeInterval(-7_000),
                    placeOfStay: nil,
                    signature: nil
                )
            ]),
            countsResult: .success([
                MonthlyOmissionCount(month: "2024-02", omissionCount: 2),
                MonthlyOmissionCount(month: "2024-01", omissionCount: 5)
            ]),
            certificatesResult: .success(
                OmissionsByStudentResponse(
                    omissionDtoList: [
                        OmissionCertificate(
                            id: 10,
                            dateFrom: baseDate.addingTimeInterval(-100),
                            dateTo: baseDate.addingTimeInterval(-50),
                            note: nil,
                            name: "Справка 1",
                            term: "ОРВИ"
                        ),
                        OmissionCertificate(
                            id: 11,
                            dateFrom: baseDate.addingTimeInterval(-10),
                            dateTo: baseDate,
                            note: nil,
                            name: "Справка 2",
                            term: "ОРВИ"
                        )
                    ],
                    faculty: "ФИТУ"
                )
            )
        )

        let viewModel = AttendanceViewModel(apiService: mockService)

        await viewModel.loadDataIfNeeded()

        XCTAssertEqual(mockService.applicationsCallCount, 1)
        XCTAssertEqual(mockService.certificatesCallCount, 1)
        XCTAssertEqual(mockService.countsCallCount, 1)

        XCTAssertEqual(viewModel.applications.map(\.id), [2, 1], "Заявки должны сортироваться по дате создания по убыванию")
        XCTAssertEqual(viewModel.certificates.map(\.id), [11, 10], "Справки должны сортироваться по дате начала по убыванию")
        XCTAssertEqual(viewModel.monthlyCounts.map(\.month), ["2024-02", "2024-01"])
        XCTAssertEqual(viewModel.faculty, "ФИТУ")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)

        await viewModel.loadDataIfNeeded()
        XCTAssertEqual(mockService.applicationsCallCount, 1, "Повторный вызов без форса не должен обращаться к API")

        await viewModel.reload()
        XCTAssertEqual(mockService.applicationsCallCount, 2)
    }

    func testLoadHandlesAPIError() async {
        let mockService = AttendanceAPIServiceMock(
            applicationsResult: .failure(APIError.serviceUnavailable(message: "Сервис недоступен")),
            countsResult: .success([]),
            certificatesResult: .success(
                OmissionsByStudentResponse(omissionDtoList: [], faculty: "ФИТУ")
            )
        )
        let viewModel = AttendanceViewModel(apiService: mockService)

        await viewModel.loadDataIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "Сервис недоступен")
        XCTAssertFalse(viewModel.isLoading)
    }
}

private final class AttendanceAPIServiceMock: APIService {
    var applicationsResult: Result<[OmissionApplication], Error>
    var countsResult: Result<[MonthlyOmissionCount], Error>
    var certificatesResult: Result<OmissionsByStudentResponse, Error>

    private(set) var applicationsCallCount = 0
    private(set) var countsCallCount = 0
    private(set) var certificatesCallCount = 0

    init(
        applicationsResult: Result<[OmissionApplication], Error>,
        countsResult: Result<[MonthlyOmissionCount], Error>,
        certificatesResult: Result<OmissionsByStudentResponse, Error>
    ) {
        self.applicationsResult = applicationsResult
        self.countsResult = countsResult
        self.certificatesResult = certificatesResult
    }

    override func getOmissionApplications() async throws -> [OmissionApplication] {
        applicationsCallCount += 1
        return try applicationsResult.get()
    }

    override func getMonthlyOmissionCounts() async throws -> [MonthlyOmissionCount] {
        countsCallCount += 1
        return try countsResult.get()
    }

    override func getOmissionsByStudent() async throws -> OmissionsByStudentResponse {
        certificatesCallCount += 1
        return try certificatesResult.get()
    }
}

private extension OmissionApplication {
    init(
        id: Int,
        status: String,
        number: Int,
        createdDate: Date,
        rejectionReason: String?,
        omissionCertificateType: String,
        dateFrom: Date,
        dateTo: Date,
        placeOfStay: String?,
        signature: String?
    ) {
        let payload: [String: Any] = [
            "id": id,
            "status": status,
            "number": number,
            "createdDate": createdDate.timeIntervalSince1970 * 1000,
            "rejectionReason": rejectionReason as Any,
            "omissionCertificateType": omissionCertificateType,
            "dateFrom": dateFrom.timeIntervalSince1970 * 1000,
            "dateTo": dateTo.timeIntervalSince1970 * 1000,
            "placeOfStay": placeOfStay as Any,
            "signature": signature as Any
        ]
        self = OmissionApplication.decode(payload)
    }

    private static func decode(_ payload: [String: Any]) -> OmissionApplication {
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder = JSONDecoder()
        return try! decoder.decode(OmissionApplication.self, from: data)
    }
}

private extension OmissionCertificate {
    init(
        id: Int,
        dateFrom: Date,
        dateTo: Date,
        note: String?,
        name: String,
        term: String
    ) {
        let payload: [String: Any] = [
            "id": id,
            "dateFrom": dateFrom.timeIntervalSince1970 * 1000,
            "dateTo": dateTo.timeIntervalSince1970 * 1000,
            "note": note as Any,
            "name": name,
            "term": term
        ]
        self = OmissionCertificate.decode(payload)
    }

    private static func decode(_ payload: [String: Any]) -> OmissionCertificate {
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder = JSONDecoder()
        return try! decoder.decode(OmissionCertificate.self, from: data)
    }
}
