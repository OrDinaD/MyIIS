import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case logoCopy5 = "logo copy 5"
    case logo = "logo"
    case logoCopy = "logo copy"
    case logoCopy2 = "logo copy 2"
    case logoCopy3 = "logo copy 3"
    case logoCopy4 = "logo copy 4"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .logoCopy5: return "Основная"
        case .logo: return "Лого 1"
        case .logoCopy: return "Лого 2"
        case .logoCopy2: return "Лого 3"
        case .logoCopy3: return "Лого 4"
        case .logoCopy4: return "Лого 5"
        }
    }

    var iconName: String? {
        self == .logoCopy5 ? nil : rawValue
    }

    var previewAssetName: String {
        switch self {
        case .logoCopy5: return "AppIconPreviewLogoCopy5"
        case .logo: return "AppIconPreviewLogo"
        case .logoCopy: return "AppIconPreviewLogoCopy"
        case .logoCopy2: return "AppIconPreviewLogoCopy2"
        case .logoCopy3: return "AppIconPreviewLogoCopy3"
        case .logoCopy4: return "AppIconPreviewLogoCopy4"
        }
    }
}

enum AppIconManager {
    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var currentIcon: AppIconOption {
        guard let current = UIApplication.shared.alternateIconName else {
            return .logoCopy5
        }

        return AppIconOption(rawValue: current) ?? .logoCopy5
    }

    @MainActor
    static func setIcon(_ option: AppIconOption) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(option.iconName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
