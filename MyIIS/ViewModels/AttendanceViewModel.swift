import Foundation

@MainActor
class AttendanceViewModel: ObservableObject {

    @Published var applications: [OmissionApplication] = []
    @Published var certificates: [OmissionCertificate] = []
    @Published var monthlyCounts: [MonthlyOmissionCount] = []
    @Published var faculty: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiService: APIService
    private var hasLoadedOnce = false

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func loadDataIfNeeded() async {
        await loadData(force: false)
    }

    func reload() async {
        await loadData(force: true)
    }

    private func loadData(force: Bool) async {
        if isLoading { return }
        if hasLoadedOnce && !force { return }

        isLoading = true
        errorMessage = nil

        do {
            async let applicationsTask = apiService.getOmissionApplications()
            async let countsTask = apiService.getMonthlyOmissionCounts()
            async let certificatesTask = apiService.getOmissionsByStudent()

            let (applications, counts, certificatesResponse) = try await (
                applicationsTask,
                countsTask,
                certificatesTask
            )

            self.applications = applications.sorted { $0.createdDate > $1.createdDate }
            self.monthlyCounts = counts
            self.certificates = certificatesResponse.omissionDtoList.sorted { $0.dateFrom > $1.dateFrom }
            self.faculty = certificatesResponse.faculty
            hasLoadedOnce = true
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = "Не удалось загрузить данные пропусков."
        }

        isLoading = false
    }
}
