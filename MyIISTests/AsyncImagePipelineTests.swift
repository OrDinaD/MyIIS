@testable import MyIIS
import UIKit
import XCTest

private final class PendingImageURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Deliberately leave the request pending, as on a stalled connection.
    }
    override func stopLoading() {}
}

@MainActor
final class AsyncImagePipelineTests: XCTestCase {
    func testExpiredDiskResponseAppearsWhileNetworkIsStillPending() async throws {
        let url = try XCTUnwrap(URL(string: "https://images.example.com/\(UUID().uuidString).png"))
        let cache = URLCache(memoryCapacity: 1_024 * 1_024, diskCapacity: 0, diskPath: nil)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let data = try XCTUnwrap(renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }.pngData())
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"]
        ))
        cache.storeCachedResponse(CachedURLResponse(
            response: response, data: data,
            userInfo: ["storedAt": Date().addingTimeInterval(-8 * 24 * 60 * 60)], storagePolicy: .allowed
        ), for: URLRequest(url: url))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PendingImageURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let pipeline = AsyncImagePipeline(diskCache: cache, session: session)
        let loaded = expectation(description: "Cached photo loads without waiting for the network")
        let task = Task {
            let image = await pipeline.loadImage(
                for: url, cacheIdentity: url.absoluteString, maxPixelSize: 64, rejectBlankImages: false
            )
            XCTAssertNotNil(image)
            loaded.fulfill()
        }
        await fulfillment(of: [loaded], timeout: 2)
        task.cancel()
    }
}
