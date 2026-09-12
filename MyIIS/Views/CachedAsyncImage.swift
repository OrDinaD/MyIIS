import ImageIO
import SwiftUI
import UIKit

private final class CachedAsyncImageMemoryCache: @unchecked Sendable {
    nonisolated(unsafe) private static let sharedCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    nonisolated(unsafe) private static let missingCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 500
        return cache
    }()

    nonisolated static func image(forKey key: NSString) -> UIImage? {
        sharedCache.object(forKey: key)
    }

    nonisolated static func setImage(_ image: UIImage, forKey key: NSString) {
        sharedCache.setObject(image, forKey: key, cost: image.estimatedMemoryCost)
    }

    nonisolated static func isMarkedMissing(_ identity: String) -> Bool {
        missingCache.object(forKey: identity as NSString) != nil
    }

    nonisolated static func markMissing(_ identity: String) {
        missingCache.setObject(1, forKey: identity as NSString)
    }

    nonisolated static func clearMissing(_ identity: String) {
        missingCache.removeObject(forKey: identity as NSString)
    }
}

private actor AsyncImagePipeline {
    static let shared = AsyncImagePipeline()

    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    func loadImage(for url: URL, cacheIdentity: String, maxPixelSize: CGFloat) async -> UIImage? {
        let cacheKey = cacheIdentity as NSString

        if let cachedImage = CachedAsyncImageMemoryCache.image(forKey: cacheKey) {
            return cachedImage
        }

        if CachedAsyncImageMemoryCache.isMarkedMissing(cacheIdentity) {
            return nil
        }

        if let inFlight = inFlightTasks[cacheIdentity] {
            return await inFlight.value
        }

        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            request.timeoutInterval = 8

            if let cached = URLCache.shared.cachedResponse(for: request),
               let image = downsampleImage(from: cached.data, maxPixelSize: maxPixelSize) {
                CachedAsyncImageMemoryCache.setImage(image, forKey: cacheKey)
                return image
            }

            guard !Task.isCancelled else { return nil }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return nil }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 || httpResponse.statusCode == 410 {
                        CachedAsyncImageMemoryCache.markMissing(cacheIdentity)
                        return nil
                    }
                    guard (200 ... 299).contains(httpResponse.statusCode) else {
                        return nil
                    }
                }

                guard let image = downsampleImage(from: data, maxPixelSize: maxPixelSize) else {
                    CachedAsyncImageMemoryCache.markMissing(cacheIdentity)
                    return nil
                }
                guard !Task.isCancelled else { return nil }

                CachedAsyncImageMemoryCache.setImage(image, forKey: cacheKey)
                URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[cacheIdentity] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: cacheIdentity)
        return result
    }

    private func downsampleImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        ImageDownsampler.image(from: data, maxPixelSize: maxPixelSize)
    }
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

struct CachedAsyncImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    var maxPixelSize: CGFloat = 1_024
    var transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18))
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure

    @State private var uiImage: UIImage?
    @State private var isFailed = false
    @State private var loadedCacheKey: String?

    init(
        url: URL?,
        maxPixelSize: CGFloat = 1_024,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else if isFailed {
                failure()
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
            isFailed = true
            return
        }
        guard loadedCacheKey != cacheIdentity else { return }
        loadedCacheKey = cacheIdentity

        let cacheKey = cacheIdentity as NSString
        if let cachedImage = CachedAsyncImageMemoryCache.image(forKey: cacheKey) {
            uiImage = cachedImage
            isFailed = false
            return
        }

        if CachedAsyncImageMemoryCache.isMarkedMissing(cacheIdentity) {
            uiImage = nil
            isFailed = true
            return
        }

        uiImage = nil
        isFailed = false

        if let image = await AsyncImagePipeline.shared.loadImage(
            for: url,
            cacheIdentity: cacheIdentity,
            maxPixelSize: maxPixelSize
        ) {
            guard !Task.isCancelled, loadedCacheKey == cacheIdentity else { return }
            withTransaction(transaction) {
                uiImage = image
                isFailed = false
            }
            return
        }

        guard !Task.isCancelled, loadedCacheKey == cacheIdentity else { return }
        isFailed = true
    }
}

extension CachedAsyncImage where Failure == Placeholder {
    init(
        url: URL?,
        maxPixelSize: CGFloat = 1_024,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            maxPixelSize: maxPixelSize,
            transaction: transaction,
            content: content,
            placeholder: placeholder,
            failure: placeholder
        )
    }
}

private extension UIImage {
    nonisolated var estimatedMemoryCost: Int {
        if let cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }

        return Int(size.width * scale * size.height * scale) * 4
    }
}
