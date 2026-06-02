import SwiftUI
import UIKit

struct GradebookSharePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let payload: GradebookShareImagePayload
    @State private var isShowingShareSheet = false
    @State private var isSavingImage = false
    @State private var saveMessage: GradebookShareSaveMessage?
    @State private var imageSaver = GradebookShareImageSaver()

    var body: some View {
        NavigationStack {
            ZoomableImageScrollView(image: payload.image)
                .background(Color(uiColor: .systemBackground))
                .navigationTitle(NSLocalizedString("gradebook_share_preview_title", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(NSLocalizedString("common_close", comment: "")) {
                            dismiss()
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(action: saveImage) {
                            if isSavingImage {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(NSLocalizedString("gradebook_share_save", comment: ""), systemImage: "square.and.arrow.down")
                            }
                        }
                        .disabled(isSavingImage)

                        Button {
                            isShowingShareSheet = true
                        } label: {
                            Label(NSLocalizedString("gradebook_share", comment: ""), systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: [payload.url])
        }
        .alert(item: $saveMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text(NSLocalizedString("common_ok", comment: "")))
            )
        }
    }

    private func saveImage() {
        isSavingImage = true
        imageSaver.save(payload.image) { error in
            Task { @MainActor in
                isSavingImage = false
                if let error {
                    saveMessage = GradebookShareSaveMessage(
                        title: NSLocalizedString("common_error", comment: ""),
                        message: error.localizedDescription
                    )
                } else {
                    saveMessage = GradebookShareSaveMessage(
                        title: NSLocalizedString("common_success", comment: ""),
                        message: NSLocalizedString("gradebook_share_saved", comment: "")
                    )
                }
            }
        }
    }
}

private struct GradebookShareSaveMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = UIImageView(image: image)

        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .systemBackground

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}

private final class GradebookShareImageSaver: NSObject {
    private var completion: ((Error?) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Error?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(saveCompleted(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func saveCompleted(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer
    ) {
        completion?(error)
        completion = nil
    }
}

#if DEBUG
#Preview {
    GradebookSharePreviewView(
        payload: GradebookShareImagePayload(
            url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("preview.png"),
            image: UIImage(systemName: "doc.richtext") ?? UIImage()
        )
    )
}
#endif
