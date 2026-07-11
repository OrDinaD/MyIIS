import Combine
import SwiftUI

struct ActivitiesServiceView: View {
    @StateObject private var viewModel = ActivitiesServiceViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.staleErrorMessage) {
                        await viewModel.reload()
                    }
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_activities_brsm_title", comment: ""),
                    subtitle: NSLocalizedString("services_activities_brsm_subtitle", comment: ""),
                    icon: "checkmark.seal.fill"
                ) {
                    MembershipStateRow(isMember: viewModel.isBRSM)
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_activities_profkom_title", comment: ""),
                    subtitle: NSLocalizedString("services_activities_profkom_subtitle", comment: ""),
                    icon: "person.2.fill"
                ) {
                    MembershipStateRow(isMember: viewModel.isProfCom)
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_activities_social_title", comment: ""),
                    subtitle: NSLocalizedString("services_activities_social_subtitle", comment: ""),
                    icon: "hands.sparkles.fill"
                ) {
                    if viewModel.socialWork.isEmpty {
                        ServiceEmptyState(text: NSLocalizedString("activities_empty", comment: ""))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(viewModel.socialWork.enumerated()), id: \.offset) { _, item in
                                ServiceJSONItemCard(item: item)
                            }
                        }
                    }
                }

                ServiceEndpointSection(
                    title: NSLocalizedString("services_activities_science_title", comment: ""),
                    subtitle: NSLocalizedString("services_activities_science_subtitle", comment: ""),
                    icon: "atom"
                ) {
                    if viewModel.researchWork.isEmpty {
                        ServiceEmptyState(text: NSLocalizedString("activities_empty", comment: ""))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(viewModel.researchWork.enumerated()), id: \.offset) { _, item in
                                ServiceJSONItemCard(item: item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NSLocalizedString("services_item_activities", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .overlay {
            if viewModel.isLoading && !viewModel.hasAnyContent {
                ProgressView(NSLocalizedString("common_loading", comment: ""))
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
        .alert(NSLocalizedString("common_error", comment: ""), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.errorMessage = nil
                }
            }
        ), actions: {
            Button(NSLocalizedString("common_ok", comment: "")) { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }
}

@MainActor
private final class ActivitiesServiceViewModel: ObservableObject {
    @Published var isBRSM: Bool?
    @Published var isProfCom: Bool?
    @Published var socialWork: [ServiceJSONObject] = []
    @Published var researchWork: [ServiceJSONObject] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isShowingStaleDataWarning = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var staleErrorMessage: String?

    private let api = ServiceEndpointsAPI()
    private var hasLoadedOnce = false
    private static let cacheKey = "ActivitiesServiceViewModel.snapshot"
    private static let brsmCacheKey = "ActivitiesServiceViewModel.brsm"
    private static let profComCacheKey = "ActivitiesServiceViewModel.profCom"
    private static let socialWorkCacheKey = "ActivitiesServiceViewModel.socialWork"
    private static let researchWorkCacheKey = "ActivitiesServiceViewModel.researchWork"

    private struct Snapshot: Codable {
        let isBRSM: Bool?
        let isProfCom: Bool?
        let socialWork: [ServiceJSONObject]
        let researchWork: [ServiceJSONObject]
    }

    init() {
        _ = restoreSnapshot(markStale: false, message: nil)
    }

    var hasAnyContent: Bool {
        lastUpdateTime != nil || isBRSM != nil || isProfCom != nil || !socialWork.isEmpty || !researchWork.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await reload()
    }

    func reload() async {
        if isLoading { return }
        if !hasAnyContent {
            _ = restoreSnapshot(markStale: false, message: nil)
        }
        isLoading = true
        defer { isLoading = false }

        let outcomes: [LoadOutcome] = [
            await loadSection(fetch: { try await api.fetchIsBRSM() }, cacheKey: Self.brsmCacheKey, assign: { value in
                isBRSM = value
            }),
            await loadSection(fetch: { try await api.fetchIsProfCom() }, cacheKey: Self.profComCacheKey, assign: { value in
                isProfCom = value
            }),
            await loadSection(fetch: { try await api.fetchSocialWork() }, cacheKey: Self.socialWorkCacheKey, assign: { value in
                socialWork = value
            }),
            await loadSection(fetch: { try await api.fetchResearchWork() }, cacheKey: Self.researchWorkCacheKey, assign: { value in
                researchWork = value
            })
        ]

        var loadedAnySection = false
        var firstErrorMessage: String?
        for outcome in outcomes {
            switch outcome {
            case .loaded:
                loadedAnySection = true
            case .failed(let message):
                firstErrorMessage = firstErrorMessage ?? message
            case .cancelled:
                return
            }
        }

        if loadedAnySection {
            let snapshot = Snapshot(isBRSM: isBRSM, isProfCom: isProfCom, socialWork: socialWork, researchWork: researchWork)
            _ = ServiceEndpointCache.save(snapshot, for: Self.cacheKey)
            hasLoadedOnce = true
            isShowingStaleDataWarning = firstErrorMessage != nil
            staleErrorMessage = firstErrorMessage
            errorMessage = nil
            return
        }

        if restoreSnapshot(markStale: true, message: firstErrorMessage) {
            errorMessage = nil
        } else {
            errorMessage = firstErrorMessage
        }
    }

    private func restoreSnapshot(markStale: Bool, message: String?) -> Bool {
        var restoredAnySection = false

        if let cachedBRSM = ServiceEndpointCache.restore(for: Self.brsmCacheKey, as: Bool.self) {
            isBRSM = cachedBRSM.value
            updateLastUpdateTime(cachedBRSM.updatedAt)
            restoredAnySection = true
        }

        if let cachedProfCom = ServiceEndpointCache.restore(for: Self.profComCacheKey, as: Bool.self) {
            isProfCom = cachedProfCom.value
            updateLastUpdateTime(cachedProfCom.updatedAt)
            restoredAnySection = true
        }

        if let cachedSocialWork = ServiceEndpointCache.restore(for: Self.socialWorkCacheKey, as: [ServiceJSONObject].self) {
            socialWork = cachedSocialWork.value
            updateLastUpdateTime(cachedSocialWork.updatedAt)
            restoredAnySection = true
        }

        if let cachedResearchWork = ServiceEndpointCache.restore(for: Self.researchWorkCacheKey, as: [ServiceJSONObject].self) {
            researchWork = cachedResearchWork.value
            updateLastUpdateTime(cachedResearchWork.updatedAt)
            restoredAnySection = true
        }

        if !restoredAnySection,
           let cached = ServiceEndpointCache.restore(for: Self.cacheKey, as: Snapshot.self) {
            apply(snapshot: cached.value, updatedAt: cached.updatedAt)
            restoredAnySection = true
        }

        guard restoredAnySection else { return false }
        if markStale {
            hasLoadedOnce = true
        }
        isShowingStaleDataWarning = markStale
        staleErrorMessage = markStale ? message : nil
        return true
    }

    private func apply(snapshot: Snapshot, updatedAt: Date) {
        isBRSM = snapshot.isBRSM
        isProfCom = snapshot.isProfCom
        socialWork = snapshot.socialWork
        researchWork = snapshot.researchWork
        updateLastUpdateTime(updatedAt)
    }

    private func updateLastUpdateTime(_ updatedAt: Date) {
        if let current = lastUpdateTime {
            lastUpdateTime = max(current, updatedAt)
        } else {
            lastUpdateTime = updatedAt
        }
    }

    private func displayMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func loadSection<T: Codable>(
        fetch: () async throws -> T,
        cacheKey: String,
        assign: (T) -> Void
    ) async -> LoadOutcome {
        do {
            let value = try await fetch()
            assign(value)
            updateLastUpdateTime(ServiceEndpointCache.save(value, for: cacheKey))
            return .loaded
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(displayMessage(for: error))
        }
    }

    private enum LoadOutcome {
        case loaded
        case failed(String)
        case cancelled
    }
}
