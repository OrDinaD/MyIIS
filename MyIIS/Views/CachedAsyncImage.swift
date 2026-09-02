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

private struct SendableImage: @unchecked Sendable {
    let value: UIImage
}

nonisolated private func downsampleImage(from data: Data, maxPixelSize: CGFloat) async -> UIImage? {
    let box = await Task.detached(priority: .userInitiated) {
        ImageDownsampler.image(from: data, maxPixelSize: maxPixelSize)
            .map(SendableImage.init(value:))
    }.value
    return box?.value
}

enum ImageDownsampler {
    nonisolated static func image(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
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

        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        request.timeoutInterval = 15

        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = await downsampleImage(from: cached.data, maxPixelSize: maxPixelSize) {
            guard !Task.isCancelled else { return }
            CachedAsyncImageMemoryCache.shared.setObject(image, forKey: cacheKey, cost: image.estimatedMemoryCost)
            withTransaction(transaction) {
                uiImage = image
            }
            return
        }

        for attempt in 0 ..< 3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }

                if let httpResponse = response as? HTTPURLResponse,
                   !(200 ... 299).contains(httpResponse.statusCode) {
                    if attempt < 2 {
                        try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 350_000_000)
                    }
                    continue
                }

                guard let image = await downsampleImage(from: data, maxPixelSize: maxPixelSize) else {
                    if attempt < 2 {
                        try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 350_000_000)
                    }
                    continue
                }
                guard !Task.isCancelled else { return }

                CachedAsyncImageMemoryCache.shared.setObject(image, forKey: cacheKey, cost: image.estimatedMemoryCost)
                URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
                withTransaction(transaction) {
                    uiImage = image
                }
                return
            } catch is CancellationError {
                return
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 350_000_000)
                }
            }
        }

        if loadedCacheKey == cacheIdentity {
            loadedCacheKey = nil
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
