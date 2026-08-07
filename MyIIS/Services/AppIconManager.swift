import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case defaultIcon = "Default"
    case retro1964 = "1964"
    case ksis = "KSIS"
    case bright
    case pink
    case purple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultIcon:
            return NSLocalizedString("plus_icon_name_default", comment: "")
        case .retro1964:
            return NSLocalizedString("plus_icon_name_1964", comment: "")
        case .ksis:
            return NSLocalizedString("plus_icon_name_ksis", comment: "")
        case .bright:
            return NSLocalizedString("plus_icon_name_bright", comment: "")
        case .pink:
            return NSLocalizedString("plus_icon_name_pink", comment: "")
        case .purple:
            return NSLocalizedString("plus_icon_name_purple", comment: "")
        }
    }

    var iconName: String? {
        self == .defaultIcon ? nil : rawValue
    }

    var previewAssetName: String {
        switch self {
        case .defaultIcon:
            return "AppIconPreviewLogoCopy5"
        case .retro1964:
            return "AppIconPreviewLogo"
        case .ksis:
            return "AppIconPreviewLogoCopy"
        case .bright:
            return "AppIconPreviewLogoCopy2"
        case .pink:
            return "AppIconPreviewLogoCopy3"
        case .purple:
            return "AppIconPreviewLogoCopy4"
        }
    }
}

enum AppIconManager {
    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var currentIcon: AppIconOption {
        guard let current = UIApplication.shared.alternateIconName else {
            return .defaultIcon
        }

        return AppIconOption(rawValue: current) ?? .defaultIcon
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
