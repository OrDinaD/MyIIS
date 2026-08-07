import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseManager {
    enum PlusPurchaseOutcome {
        case purchased
        case pending
        case cancelled
    }

    enum PurchaseError: Error {
        case productUnavailable
        case failedVerification
    }

    static let shared = PurchaseManager()
    static let plusProductID = "myiis.plus.lifetime"

    private(set) var plusProduct: Product?
    private(set) var hasPlus = false
    private(set) var isLoading = false

    private var hasPrepared = false
    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case let .verified(transaction) = result,
                      transaction.productID == Self.plusProductID else {
                    continue
                }

                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true
        await reload()
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        await loadProduct()
        await refreshEntitlements()
    }

    func purchasePlus() async throws -> PlusPurchaseOutcome {
        guard let plusProduct else {
            throw PurchaseError.productUnavailable
        }

        switch try await plusProduct.purchase() {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                throw PurchaseError.failedVerification
            }

            hasPlus = true
            await transaction.finish()
            return .purchased

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func loadProduct() async {
        do {
            plusProduct = try await Product.products(for: [Self.plusProductID]).first
        } catch {
            plusProduct = nil
        }
    }

    private func refreshEntitlements() async {
        var isEntitled = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.plusProductID,
                  transaction.revocationDate == nil else {
                continue
            }

            isEntitled = true
            break
        }

        hasPlus = isEntitled
    }
}
