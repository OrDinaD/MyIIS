@testable import MyIIS
import XCTest

@MainActor
final class ScreenshotBrandTests: XCTestCase {

    // MARK: - Dynamic Island Tests

    func testDynamicIslandResolution_iPhone14ProAnd15And16Family() {
        let identifiers = [
            "iPhone15,2", // 14 Pro
            "iPhone15,3", // 14 Pro Max
            "iPhone15,4", // 15
            "iPhone15,5", // 15 Plus
            "iPhone16,1", // 15 Pro
            "iPhone16,2", // 15 Pro Max
            "iPhone17,3", // 16
            "iPhone17,4"  // 16 Plus
        ]

        for id in identifiers {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected geometry for \(id)")
                continue
            }
            XCTAssertEqual(geometry.type, .dynamicIsland, "Device \(id) should be dynamicIsland")
            XCTAssertEqual(geometry.maxWidth, 122.0, "Device \(id) maxWidth should be 122.0")
            XCTAssertEqual(geometry.maxHeight, 36.7, "Device \(id) maxHeight should be 36.7")
            XCTAssertEqual(geometry.topOffset, 11.3, "Device \(id) topOffset should be 11.3")
        }
    }

    func testDynamicIslandResolution_iPhone16ProAnd17Family() {
        let identifiers = [
            "iPhone17,1", // 16 Pro
            "iPhone17,2", // 16 Pro Max
            "iPhone18,1", // 17 Pro
            "iPhone18,2", // 17 Pro Max
            "iPhone18,3"  // 17
        ]

        for id in identifiers {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected geometry for \(id)")
                continue
            }
            XCTAssertEqual(geometry.type, .dynamicIsland, "Device \(id) should be dynamicIsland")
            XCTAssertEqual(geometry.maxWidth, 122.0, "Device \(id) maxWidth should be 122.0")
            XCTAssertEqual(geometry.maxHeight, 36.7, "Device \(id) maxHeight should be 36.7")
            XCTAssertEqual(geometry.topOffset, 14.0, "Device \(id) topOffset should be 14.0")
        }
    }

    func testDynamicIslandResolution_iPhoneAir() {
        let id = "iPhone18,4" // iPhone Air
        guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
            XCTFail("Expected geometry for \(id)")
            return
        }
        XCTAssertEqual(geometry.type, .dynamicIsland)
        XCTAssertEqual(geometry.maxWidth, 122.0)
        XCTAssertEqual(geometry.maxHeight, 36.7)
        XCTAssertEqual(geometry.topOffset, 20.0)
    }

    // MARK: - Notch Tests

    func testNotchResolution_iPhoneXAndXsAnd11ProFamily() {
        let identifiers = ["iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone12,3", "iPhone12,5"]

        for id in identifiers {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected notch geometry for \(id)")
                continue
            }
            XCTAssertEqual(geometry.type, .notch)
            XCTAssertEqual(geometry.maxWidth, 209.0)
            XCTAssertEqual(geometry.maxHeight, 30.0)
            XCTAssertEqual(geometry.topOffset, 0.0)
        }
    }

    func testNotchResolution_iPhoneXrAnd11() {
        let identifiers = ["iPhone11,8", "iPhone12,1"]

        for id in identifiers {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected notch geometry for \(id)")
                continue
            }
            XCTAssertEqual(geometry.type, .notch)
            XCTAssertEqual(geometry.maxWidth, 230.0)
            XCTAssertEqual(geometry.maxHeight, 33.0)
            XCTAssertEqual(geometry.topOffset, 0.0)
        }
    }

    func testNotchResolution_iPhone12Family() {
        let identifiers = ["iPhone13,2", "iPhone13,3", "iPhone13,4"]

        for id in identifiers {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected notch geometry for \(id)")
                continue
            }
            XCTAssertEqual(geometry.type, .notch)
            XCTAssertEqual(geometry.maxWidth, 211.0)
            XCTAssertEqual(geometry.maxHeight, 32.2)
            XCTAssertEqual(geometry.topOffset, 0.0)
        }
    }

    func testNotchResolution_iPhone12MiniAnd13Mini() {
        guard let mini12 = HardwareCutoutGeometry.resolve(for: "iPhone13,1") else {
            XCTFail("Expected notch geometry for iPhone 12 Mini")
            return
        }
        XCTAssertEqual(mini12.type, .notch)
        XCTAssertEqual(mini12.maxWidth, 226.0)
        XCTAssertEqual(mini12.maxHeight, 34.7)

        guard let mini13 = HardwareCutoutGeometry.resolve(for: "iPhone14,4") else {
            XCTFail("Expected notch geometry for iPhone 13 Mini")
            return
        }
        XCTAssertEqual(mini13.type, .notch)
        XCTAssertEqual(mini13.maxWidth, 175.0)
        XCTAssertEqual(mini13.maxHeight, 37.4)
    }

    func testNotchResolution_iPhone13And14And16eAnd17eFamily() {
        let identifiers = ["iPhone14,2", "iPhone14,3", "iPhone14,5", "iPhone14,7", "iPhone14,8", "iPhone17,5", "iPhone18,5"]

        for id in identifiers {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected notch geometry for \(id)")
                continue
            }
            XCTAssertEqual(geometry.type, .notch)
            XCTAssertEqual(geometry.maxWidth, 162.0)
            XCTAssertEqual(geometry.maxHeight, 33.0)
            XCTAssertEqual(geometry.topOffset, 0.0)
        }
    }

    // MARK: - Safety & Boundary Tests

    func testUnsupportedDevicesReturnNil() {
        let unsupported = [
            "iPad13,4",
            "iPad8,1",
            "Macmini9,1",
            "iPod9,1",
            "UnknownDevice",
            "",
            "iPhone99,99"
        ]

        for id in unsupported {
            XCTAssertNil(HardwareCutoutGeometry.resolve(for: id), "Device \(id) must return nil")
        }
    }

    func testIdentifierResolutionAcceptsRawSuffix() {
        XCTAssertNotNil(HardwareCutoutGeometry.resolve(for: "17,1"))
        XCTAssertEqual(
            HardwareCutoutGeometry.resolve(for: "17,1"),
            HardwareCutoutGeometry.resolve(for: "iPhone17,1")
        )
    }

    func testBadgeDimensionsAreWithinHardwareBounds() {
        let testDevices = [
            "iPhone15,2", "iPhone17,1", "iPhone18,4",
            "iPhone10,6", "iPhone11,8", "iPhone13,2",
            "iPhone14,5", "iPhone17,5"
        ]

        let badgeHeight: CGFloat = 30.0
        let badgeMaxWidth: CGFloat = 116.0

        for id in testDevices {
            guard let geometry = HardwareCutoutGeometry.resolve(for: id) else {
                XCTFail("Expected geometry for \(id)")
                continue
            }
            XCTAssertLessThanOrEqual(badgeHeight, geometry.maxHeight, "Badge height must not exceed cutout height for \(id)")
            XCTAssertLessThanOrEqual(badgeMaxWidth, geometry.maxWidth, "Badge width must not exceed cutout width for \(id)")
        }
    }
}
