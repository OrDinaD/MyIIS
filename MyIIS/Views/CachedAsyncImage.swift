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
        guard let expiresAt = missingCache.object(forKey: identity as NSString) else { return false }
        return expiresAt.doubleValue > Date().timeIntervalSince1970
    }

    nonisolated static func markMissing(_ identity: String) {
        missingCache.setObject(NSNumber(value: Date().addingTimeInterval(600).timeIntervalSince1970), forKey: identity as NSString)
    }

    nonisolated static func clearMissing(_ identity: String) {
        missingCache.removeObject(forKey: identity as NSString)
    }
}

private actor AsyncImagePipeline {
    static let shared = AsyncImagePipeline()

    private let diskCache = URLCache(
        memoryCapacity: 16 * 1024 * 1024,
        diskCapacity: 256 * 1024 * 1024,
        directory: URL.cachesDirectory.appendingPathComponent("MyIISImages", isDirectory: true)
    )
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    func loadImage(for url: URL, cacheIdentity: String, maxPixelSize: CGFloat, rejectBlankImages: Bool) async -> UIImage? {
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
            await loadUncachedImage(url: url, cacheIdentity: cacheIdentity, maxPixelSize: maxPixelSize, rejectBlankImages: rejectBlankImages)
        }

        inFlightTasks[cacheIdentity] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: cacheIdentity)
        return result
    }

    private func loadUncachedImage(
        url: URL, cacheIdentity: String, maxPixelSize: CGFloat, rejectBlankImages: Bool
    ) async -> UIImage? {
        let cacheKey = cacheIdentity as NSString
        let canonicalURL = SchedulePhotoRouting.canonicalURL(url)
        let request = URLRequest(url: canonicalURL)
        let cached = diskCache.cachedResponse(for: request)
        let cachedAt = cached?.userInfo?["storedAt"] as? Date ?? .distantPast
        if let cached, Date().timeIntervalSince(cachedAt) < 7 * 24 * 60 * 60,
           let image = downsampleImage(from: cached.data, maxPixelSize: maxPixelSize, rejectBlankImages: rejectBlankImages) {
            CachedAsyncImageMemoryCache.setImage(image, forKey: cacheKey)
            return image
        }

        var urls = [canonicalURL]
        if await ScheduleServerConfiguration.selectedServer != .official,
           let gatewayURL = SchedulePhotoRouting.gatewayURL(for: canonicalURL),
           await ScheduleGatewayHealth.shared.shouldAttempt() {
            urls.insert(gatewayURL, at: 0)
        }
        for candidate in urls {
            guard !Task.isCancelled else { return nil }
            let isGateway = candidate.host == "bsuir.ordinad.xyz"
            var networkRequest = URLRequest(url: candidate, cachePolicy: .reloadIgnoringLocalCacheData)
            networkRequest.timeoutInterval = isGateway ? 1.5 : 8
            do {
                let transport = isGateway ? ScheduleGatewaySession.shared : session
                let (data, response) = try await transport.data(for: networkRequest)
                guard !Task.isCancelled else { return nil }
                guard let http = response as? HTTPURLResponse,
                      (200 ... 299).contains(http.statusCode),
                      let image = downsampleImage(from: data, maxPixelSize: maxPixelSize, rejectBlankImages: rejectBlankImages) else {
                    if isGateway {
                        await ScheduleGatewayHealth.shared.failed()
                        continue
                    }
                    if let http = response as? HTTPURLResponse, [404, 410].contains(http.statusCode) {
                        diskCache.removeCachedResponse(for: request)
                        CachedAsyncImageMemoryCache.markMissing(cacheIdentity)
                        return nil
                    }
                    break
                }
                if isGateway { await ScheduleGatewayHealth.shared.succeeded() }
                CachedAsyncImageMemoryCache.setImage(image, forKey: cacheKey)
                diskCache.storeCachedResponse(
                    CachedURLResponse(response: response, data: data, userInfo: ["storedAt": Date()], storagePolicy: .allowed),
                    for: request
                )
                return image
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    if isGateway { await ScheduleGatewayHealth.shared.cancelled() }
                    return nil
                }
                if isGateway { await ScheduleGatewayHealth.shared.failed() }
            }
        }
        // Keep already downloaded photos available offline, even after their refresh date.
        if let cached, let image = downsampleImage(
            from: cached.data, maxPixelSize: maxPixelSize, rejectBlankImages: rejectBlankImages
        ) {
            CachedAsyncImageMemoryCache.setImage(image, forKey: cacheKey)
            return image
        }
        return nil
    }

    private func downsampleImage(from data: Data, maxPixelSize: CGFloat, rejectBlankImages: Bool) -> UIImage? {
        guard let image = ImageDownsampler.image(from: data, maxPixelSize: maxPixelSize) else { return nil }
        return rejectBlankImages && TeacherPhotoValidation.isBlank(image.cgImage) ? nil : image
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
    var rejectBlankImages: Bool = false
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
        rejectBlankImages: Bool = false,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.rejectBlankImages = rejectBlankImages
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
        return "\(SchedulePhotoRouting.canonicalURL(url).absoluteString)#\(Int(maxPixelSize.rounded(.up)))#\(rejectBlankImages)"
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
        defer {
            if Task.isCancelled, loadedCacheKey == cacheIdentity {
                loadedCacheKey = nil
            }
        }

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
            maxPixelSize: maxPixelSize,
            rejectBlankImages: rejectBlankImages
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
        rejectBlankImages: Bool = false,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18)),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            maxPixelSize: maxPixelSize,
            rejectBlankImages: rejectBlankImages,
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
