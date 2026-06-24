import SwiftUI
import UIKit

private final class CachedAsyncImageMemoryCache {
    static let shared = NSCache<NSURL, UIImage>()
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    var transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18))
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() async {
        guard loadedURL != url else { return }
        loadedURL = url
        uiImage = nil

        guard let url else { return }
        let cacheKey = url as NSURL
        if let cachedImage = CachedAsyncImageMemoryCache.shared.object(forKey: cacheKey) {
            withTransaction(transaction) {
                uiImage = cachedImage
            }
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)

        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cached.data) {
            CachedAsyncImageMemoryCache.shared.setObject(image, forKey: cacheKey)
            withTransaction(transaction) {
                uiImage = image
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled, let image = UIImage(data: data) else { return }
            CachedAsyncImageMemoryCache.shared.setObject(image, forKey: cacheKey)
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            withTransaction(transaction) {
                uiImage = image
            }
        } catch {
            if Task.isCancelled { return }
        }
    }
}
