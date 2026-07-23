import AVFoundation
import SwiftUI
import UIKit

struct FirstLaunchVideoView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var hapticObserver: Any?
    @State private var didFinish = false

    let onFinished: () -> Void

    private static let hapticCueTimes = [0.15, 1.69, 3.91, 5.91].map {
        NSValue(time: CMTime(seconds: $0, preferredTimescale: 600))
    }

    var body: some View {
        PlayerLayerSurface(player: player)
            .background(Color(red: 0.53, green: 0.67, blue: 0.76))
            .accessibilityHidden(true)
            .task {
                startPlaybackIfNeeded()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            ) { notification in
                guard notification.object as? AVPlayerItem === player?.currentItem else {
                    return
                }
                finishPlayback()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            ) { notification in
                guard notification.object as? AVPlayerItem === player?.currentItem else {
                    return
                }
                finishPlayback()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard !didFinish else { return }

                if newPhase == .active {
                    player?.play()
                } else {
                    player?.pause()
                }
            }
            .onDisappear {
                removeHapticObserver()
                player?.pause()
            }
    }

    private func startPlaybackIfNeeded() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(
            forResource: "MyIIS-icon-assembly-trimmed",
            withExtension: "mp4"
        ) else {
            finishPlayback()
            return
        }

        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
        self.player = player

        FirstLaunchHapticPlayer.shared.prepare()
        hapticObserver = player.addBoundaryTimeObserver(
            forTimes: Self.hapticCueTimes,
            queue: .main
        ) {
            Task { @MainActor in
                FirstLaunchHapticPlayer.shared.playSoftImpact()
            }
        }

        player.playImmediately(atRate: 1.5)
    }

    private func finishPlayback() {
        guard !didFinish else { return }
        didFinish = true
        removeHapticObserver()
        player?.pause()
        onFinished()
    }

    private func removeHapticObserver() {
        guard let hapticObserver else { return }
        player?.removeTimeObserver(hapticObserver)
        self.hapticObserver = nil
    }
}

@MainActor
private final class FirstLaunchHapticPlayer {
    static let shared = FirstLaunchHapticPlayer()

    private let generator = UIImpactFeedbackGenerator(style: .soft)

    private init() {}

    func prepare() {
        generator.prepare()
    }

    func playSoftImpact() {
        generator.impactOccurred(intensity: 0.42)
        generator.prepare()
    }
}

private struct PlayerLayerSurface: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerSurfaceView, context: Context) {
        view.playerLayer.player = player
    }
}

private class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            preconditionFailure("PlayerSurfaceView requires AVPlayerLayer")
        }
        return playerLayer
    }
}
