@testable import MyIIS
import SwiftUI
import XCTest

@MainActor
final class ImagePickerTests: XCTestCase {

    func testCoordinatorDidFinishPickingMedia() {
        var selectedImage: UIImage?
        let binding = Binding(get: { selectedImage }, set: { selectedImage = $0 })

        let picker = ImagePicker(selectedImage: binding, sourceType: .photoLibrary)
        let coordinator = picker.makeCoordinator()

        let uiImage = UIImage()
        let info: [UIImagePickerController.InfoKey: Any] = [.originalImage: uiImage]

        let mockPickerController = UIImagePickerController()

        coordinator.imagePickerController(mockPickerController, didFinishPickingMediaWithInfo: info)

        XCTAssertEqual(selectedImage, uiImage)
    }

    func testCoordinatorDidCancel() {
        var selectedImage: UIImage?
        let binding = Binding(get: { selectedImage }, set: { selectedImage = $0 })

        let picker = ImagePicker(selectedImage: binding, sourceType: .photoLibrary)
        let coordinator = picker.makeCoordinator()

        let mockPickerController = UIImagePickerController()

        coordinator.imagePickerControllerDidCancel(mockPickerController)

        XCTAssertNil(selectedImage)
    }
}
