import Combine
import Foundation

@MainActor
final class StudyViewModel: ObservableObject {
    @Published private(set) var dashboard: StudyDashboard
    @Published private(set) var markSheetEmployees: [MarkSheetEmployee] = []
    @Published var isLoading = false
    @Published var isLoadingEmployees = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    @Published var lastUpdateTime: Date?
    @Published var isShowingStaleDataWarning = false

    private let service: StudyServiceProtocol
    private let userDefaults: UserDefaults
    private static let cacheKey = "StudyViewModel.dashboardSnapshot"

    private struct Snapshot: Codable {
        let dashboard: StudyDashboard
        let lastUpdateTime: Date?
    }

    init(
        service: StudyServiceProtocol? = nil,
        initialDashboard: StudyDashboard? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.service = service ?? StudyService()
        self.userDefaults = userDefaults
        if let initialDashboard {
            self.dashboard = initialDashboard
        } else if let cachedSnapshot = Self.restoreSnapshot(from: userDefaults) {
            self.dashboard = cachedSnapshot.dashboard
            self.lastUpdateTime = cachedSnapshot.lastUpdateTime
        } else {
            self.dashboard = .empty
        }
    }

    var hasLoadedContent: Bool {
        !dashboard.markSheets.isEmpty
            || !dashboard.markSheetSubjects.isEmpty
            || !dashboard.certificates.isEmpty
            || !dashboard.certificatePlaceSections.isEmpty
            || !dashboard.lmsApplications.isEmpty
    }

    var certificatePlaces: [CertificatePlace] {
        dashboard.certificatePlaceSections.flatMap(\.places)
    }

    var printedCertificatesCount: Int {
        dashboard.certificates.filter { $0.status == 1 }.count
    }

    var processingCertificatesCount: Int {
        dashboard.certificates.filter { $0.status == 2 }.count
    }

    var processingMarkSheetsCount: Int {
        dashboard.markSheets.filter(\.isProcessing).count
    }

    func load(force: Bool = false) async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        isShowingStaleDataWarning = false
        defer { isLoading = false }

        do {
            let fetchedDashboard = try await service.fetchDashboard()
            dashboard = mergedDashboardPreservingVisibleData(fetchedDashboard)
            lastUpdateTime = Date()
            saveSnapshot()
        } catch is CancellationError {
            return
        } catch let apiError as APIError {
            if hasLoadedContent {
                isShowingStaleDataWarning = true
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            let fallbackMessage = "Не удалось загрузить раздел «Учеба»."
            if hasLoadedContent {
                isShowingStaleDataWarning = true
                errorMessage = fallbackMessage
            } else {
                errorMessage = fallbackMessage
            }
        }
    }

    func refresh() async {
        await load(force: true)
    }

    func clearEmployees() {
        markSheetEmployees = []
    }

    func loadEmployees(for lessonType: MarkSheetLessonType?) async {
        guard let lessonType else {
            clearEmployees()
            return
        }

        isLoadingEmployees = true
        do {
            markSheetEmployees = try await service.fetchEmployees(for: lessonType)
        } catch {
            markSheetEmployees = []
            toastMessage = "Не удалось загрузить преподавателей."
        }
        isLoadingEmployees = false
    }

    func markSheetType(for lessonType: MarkSheetLessonType?) -> MarkSheetType? {
        guard let lessonType else { return nil }
        return dashboard.markSheetTypes.first { type in
            type.isExam == lessonType.isExam &&
            type.isOffset == lessonType.isOffset &&
            type.isCourseWork == lessonType.isCourseWork &&
            (type.isRemote == nil || type.isRemote == lessonType.isRemote)
        }
    }

    func calculatedPrice(type: MarkSheetType?, employee: MarkSheetEmployee?, hours: Int) -> Double? {
        guard let employeePrice = employee?.price else { return nil }
        let multiplier: Double
        if type?.id == 3 {
            multiplier = Double(hours)
        } else {
            multiplier = type?.coefficient ?? 1
        }
        return (multiplier * employeePrice * 100).rounded() / 100
    }

    func priceText(type: MarkSheetType?, employee: MarkSheetEmployee?, hours: Int) -> String? {
        guard let price = calculatedPrice(type: type, employee: employee, hours: hours) else { return nil }
        return String(format: "%.2f BYN", price)
    }

    func submitMarkSheet(_ request: MarkSheetOrderRequest) async -> Bool {
        if isSubmitting { return false }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let newRequest = try await service.orderMarkSheet(request)
            dashboard.markSheets.insert(newRequest, at: 0)
            saveSnapshot()
            toastMessage = "Ведомостичка заказана."
            return true
        } catch let apiError as APIError {
            toastMessage = apiError.localizedDescription
            return false
        } catch {
            toastMessage = "Не удалось заказать ведомостичку."
            return false
        }
    }

    func submitCertificate(_ request: CertificateRegisterRequest) async -> Bool {
        if isSubmitting { return false }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let newRequests = try await service.orderCertificate(request)
            dashboard.certificates.insert(contentsOf: newRequests, at: 0)
            saveSnapshot()
            toastMessage = newRequests.count > 1 ? "Справки заказаны." : "Справка заказана."
            return true
        } catch let apiError as APIError {
            toastMessage = apiError.localizedDescription
            return false
        } catch {
            toastMessage = "Не удалось заказать справку."
            return false
        }
    }

    func cancelMarkSheet(_ request: MarkSheetRequest) async {
        do {
            let updated = try await service.cancelMarkSheetRequest(id: request.id)
            replaceMarkSheet(updated)
            saveSnapshot()
            toastMessage = "Ведомостичка отменена."
        } catch {
            toastMessage = "Не удалось отменить ведомостичку."
        }
    }

    func cancelCertificate(_ request: CertificateRequest) async {
        do {
            let updated = try await service.cancelCertificateRequest(id: request.id)
            replaceCertificate(updated)
            saveSnapshot()
            toastMessage = "Справка отменена."
        } catch {
            toastMessage = "Не удалось отменить справку."
        }
    }

    private func mergedDashboardPreservingVisibleData(_ fetched: StudyDashboard) -> StudyDashboard {
        StudyDashboard(
            markSheets: fetched.markSheets.isEmpty ? dashboard.markSheets : fetched.markSheets,
            markSheetTypes: fetched.markSheetTypes.isEmpty ? dashboard.markSheetTypes : fetched.markSheetTypes,
            markSheetSubjects: fetched.markSheetSubjects.isEmpty ? dashboard.markSheetSubjects : fetched.markSheetSubjects,
            certificates: fetched.certificates.isEmpty ? dashboard.certificates : fetched.certificates,
            certificatePlaceSections: fetched.certificatePlaceSections.isEmpty ? dashboard.certificatePlaceSections : fetched.certificatePlaceSections,
            lmsApplications: fetched.lmsApplications.isEmpty ? dashboard.lmsApplications : fetched.lmsApplications
        )
    }

    private func replaceMarkSheet(_ request: MarkSheetRequest) {
        guard let index = dashboard.markSheets.firstIndex(where: { $0.id == request.id }) else { return }
        dashboard.markSheets[index] = request
    }

    private func replaceCertificate(_ request: CertificateRequest) {
        guard let index = dashboard.certificates.firstIndex(where: { $0.id == request.id }) else { return }
        dashboard.certificates[index] = request
    }

    private func saveSnapshot() {
        let snapshot = Snapshot(dashboard: dashboard, lastUpdateTime: lastUpdateTime ?? Date())
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }
        _ = UserDefaultsPayloadStore.save(payload, forKey: Self.cacheKey, in: userDefaults)
    }

    private static func restoreSnapshot(from userDefaults: UserDefaults) -> Snapshot? {
        guard let payload = UserDefaultsPayloadStore.load(forKey: cacheKey, from: userDefaults) else {
            return nil
        }
        return try? JSONDecoder().decode(Snapshot.self, from: payload)
    }
}

#if DEBUG
extension StudyViewModel {
    static var preview: StudyViewModel {
        StudyViewModel(initialDashboard: .preview)
    }
}

extension StudyDashboard {
    static let preview = StudyDashboard(
        markSheets: [
            MarkSheetRequest(
                id: 1,
                createdDate: "10.05.2026",
                absentDate: "14.05.2026",
                status: "обрабатывается",
                price: 17.25,
                subject: MarkSheetRequestSubject(abbrev: "САиИО", focsId: nil, thId: 996381),
                markSheetType: MarkSheetType(
                    id: 3, shortName: "Лаб. работа", fullName: nil, price: nil,
                    coefficient: 1, isExam: false, isOffset: false,
                    isCourseWork: false, isLab: true, isRemote: false
                ),
                employee: MarkSheetEmployee(
                    id: 504496,
                    firstName: "Екатерина",
                    lastName: "Протченко",
                    middleName: "Владимировна",
                    fio: "Протченко Е. В.",
                    academicDepartment: "Каф.ЭВМ",
                    price: 5.75
                )
            )
        ],
        markSheetTypes: [
            MarkSheetType(
                id: 3,
                shortName: "Лаб. работа",
                fullName: nil,
                price: nil,
                coefficient: 1,
                isExam: false,
                isOffset: false,
                isCourseWork: false,
                isLab: true,
                isRemote: false
            )
        ],
        markSheetSubjects: [
            MarkSheetSubject(etId: 333811, abbrev: "САиИО", term: 4, lessonTypes: [
                MarkSheetLessonType(abbrev: "ЛР", thId: 996381, focsId: nil, isExam: false, isOffset: false, isCourseWork: false, isLab: true, isRemote: false)
            ])
        ],
        certificates: [
            CertificateRequest(
                id: 205877, number: 3918, provisionPlace: "иное (Справка в ПВТ)",
                dateOrder: "27.04.2026", issueDate: "28.04.2026",
                certificateType: "обычная", status: 1, rejectionReason: nil, isByStudent: true
            )
        ],
        certificatePlaceSections: [
            CertificatePlaceSection(type: "Деканат", places: [
                CertificatePlace(name: "в ЖКХ", id: 3, type: 0),
                CertificatePlace(name: "иное", id: 16, type: 0)
            ])
        ],
        lmsApplications: []
    )
}
#endif
