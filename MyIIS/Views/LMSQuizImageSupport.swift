import SwiftUI
import UIKit

struct ZoomImageToken: Identifiable {
    let id = UUID()
    let url: URL
}

struct ZoomableImageViewer: View {
    let url: URL
    let onClose: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let image {
                ZoomableImageScrollView(image: image)
                    .ignoresSafeArea()
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text("Не удалось загрузить изображение")
                    .foregroundStyle(.white)
            }

            Button("Закрыть") {
                onClose()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding()
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            image = UIImage(data: data)
        } catch {
            image = nil
        }
    }
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.tag = 999

        scrollView.addSubview(imageView)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let imageView = uiView.viewWithTag(999) as? UIImageView else { return }
        imageView.image = image
        imageView.frame = uiView.bounds
        uiView.zoomScale = 1.0
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(999)
        }
    }
}

struct ErrorStateView: View {
    let error: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("Не удалось открыть тест")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
