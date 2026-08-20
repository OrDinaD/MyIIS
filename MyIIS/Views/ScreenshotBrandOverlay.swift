import SwiftUI

// MARK: - Hardware Cutout Types & Geometry

nonisolated enum HardwareCutoutType: Equatable, Sendable {
    case dynamicIsland
    case notch
}

nonisolated struct HardwareCutoutGeometry: Equatable, Sendable {
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let topOffset: CGFloat
    let type: HardwareCutoutType

    nonisolated static func resolve(for identifier: String) -> HardwareCutoutGeometry? {
        let model = normalizedModel(for: identifier)
        if let dynamicIsland = resolveDynamicIsland(for: model) {
            return dynamicIsland
        }
        return resolveNotch(for: model)
    }

    private nonisolated static func normalizedModel(for identifier: String) -> String {
        identifier.hasPrefix("iPhone") ? String(identifier.dropFirst(6)) : identifier
    }

    private nonisolated static func resolveDynamicIsland(for model: String) -> HardwareCutoutGeometry? {
        switch model {
        // iPhone 14 Pro, 14 Pro Max, 15, 15 Plus, 15 Pro, 15 Pro Max, 16, 16 Plus
        case "15,2", "15,3", "15,4", "15,5", "16,1", "16,2", "17,3", "17,4":
            return HardwareCutoutGeometry(
                maxWidth: 122.0,
                maxHeight: 36.7,
                topOffset: 11.3,
                type: .dynamicIsland
            )
        // iPhone 16 Pro, 16 Pro Max, 17, 17 Pro, 17 Pro Max
        case "17,1", "17,2", "18,1", "18,2", "18,3":
            return HardwareCutoutGeometry(
                maxWidth: 122.0,
                maxHeight: 36.7,
                topOffset: 14.0,
                type: .dynamicIsland
            )
        // iPhone Air
        case "18,4":
            return HardwareCutoutGeometry(
                maxWidth: 122.0,
                maxHeight: 36.7,
                topOffset: 20.0,
                type: .dynamicIsland
            )
        default:
            return nil
        }
    }

    private nonisolated static func resolveNotch(for model: String) -> HardwareCutoutGeometry? {
        switch model {
        // iPhone X, XS, XS Max, 11 Pro, 11 Pro Max
        case "10,3", "10,6", "11,2", "11,4", "11,6", "12,3", "12,5":
            return HardwareCutoutGeometry(
                maxWidth: 209.0,
                maxHeight: 30.0,
                topOffset: 0.0,
                type: .notch
            )
        // iPhone XR, iPhone 11
        case "11,8", "12,1":
            return HardwareCutoutGeometry(
                maxWidth: 230.0,
                maxHeight: 33.0,
                topOffset: 0.0,
                type: .notch
            )
        // iPhone 12, iPhone 12 Pro, iPhone 12 Pro Max
        case "13,2", "13,3", "13,4":
            return HardwareCutoutGeometry(
                maxWidth: 211.0,
                maxHeight: 32.2,
                topOffset: 0.0,
                type: .notch
            )
        // iPhone 12 Mini
        case "13,1":
            return HardwareCutoutGeometry(
                maxWidth: 226.0,
                maxHeight: 34.7,
                topOffset: 0.0,
                type: .notch
            )
        // iPhone 13 Mini
        case "14,4":
            return HardwareCutoutGeometry(
                maxWidth: 175.0,
                maxHeight: 37.4,
                topOffset: 0.0,
                type: .notch
            )
        // iPhone 13, 13 Pro, 13 Pro Max, 14, 14 Plus, 16e, 17e
        case "14,2", "14,3", "14,5", "14,7", "14,8", "17,5", "18,5":
            return HardwareCutoutGeometry(
                maxWidth: 162.0,
                maxHeight: 33.0,
                topOffset: 0.0,
                type: .notch
            )
        default:
            return nil
        }
    }
}

// MARK: - Device Identifier Helper

nonisolated enum DeviceIdentifier {
    nonisolated static var current: String {
        #if targetEnvironment(simulator)
        if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simModel.isEmpty {
            return simModel
        }
        return "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
        #endif
    }
}

// MARK: - Screenshot Brand Badge

struct MyIISScreenshotBrandBadge: View {
    private let brandBlue = Color(
        red: 0.02,
        green: 0.39,
        blue: 0.64
    )

    var body: some View {
        HStack(spacing: 5) {
            Image("ScreenshotBrandLogo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 17, height: 17)

            Text("MYIIS")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background {
            Capsule()
                .fill(brandBlue)
        }
        .fixedSize()
    }
}

// MARK: - Screenshot Brand Overlay

struct ScreenshotBrandOverlay: View {
    var deviceIdentifier: String = DeviceIdentifier.current

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.height > proxy.size.width,
               let geometry = HardwareCutoutGeometry.resolve(for: deviceIdentifier) {
                MyIISScreenshotBrandBadge()
                    .frame(
                        maxWidth: min(geometry.maxWidth - 4, 116),
                        maxHeight: min(geometry.maxHeight, 32)
                    )
                    .position(
                        x: proxy.size.width / 2,
                        y: geometry.topOffset + (geometry.maxHeight / 2)
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Screenshot brand") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        ScreenshotBrandOverlay(deviceIdentifier: "iPhone17,1")
    }
}
