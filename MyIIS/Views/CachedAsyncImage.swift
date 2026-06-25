import ImageIO
import SwiftUI
import UIKit

private final class CachedAsyncImageMemoryCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()
}

enum ImageDownsampler {
    static func image(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: image)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    var maxPixelSize: CGFloat = 1_024
    var transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18))
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var loadedCacheKey: String?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: cacheIdentity) {
            await loadImageIfNeeded()
        }
    }

    private var cacheIdentity: String? {
        guard let url else { return nil }
        return "\(url.absoluteString)#\(Int(maxPixelSize.rounded(.up)))"
    }

    private func loadImageIfNeeded() async {
        guard let url, let cacheIdentity else {
            loadedCacheKey = nil
            uiImage = nil
            return
        }
        guard loadedCacheKey != cacheIdentity else { return }
        loadedCacheKey = cacheIdentity
        uiImage = nil

        let cacheKey = cacheIdentity as NSString
        if let cachedImage = CachedAsyncImageMemoryCache.shared.object(forKey: cacheKey) {
            withTransaction(transaction) {
                uiImage = cachedImage
            }
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)

        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = ImageDownsampler.image(from: cached.data, maxPixelSize: maxPixelSize) {
            CachedAsyncImageMemoryCache.shared.setObject(image, forKey: cacheKey, cost: image.estimatedMemoryCost)
            withTransaction(transaction) {
                uiImage = image
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let image = ImageDownsampler.image(from: data, maxPixelSize: maxPixelSize) else { return }
            CachedAsyncImageMemoryCache.shared.setObject(image, forKey: cacheKey, cost: image.estimatedMemoryCost)
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            withTransaction(transaction) {
                uiImage = image
            }
        } catch {
            if Task.isCancelled { return }
        }
    }
}

private extension UIImage {
    var estimatedMemoryCost: Int {
        if let cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }

        return Int(size.width * scale * size.height * scale) * 4
    }
}
