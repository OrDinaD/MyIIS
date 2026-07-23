import AVFoundation
import SwiftUI
import UIKit

struct FirstLaunchVideoView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var didFinish = false

    let onFinished: () -> Void

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
        player.playImmediately(atRate: 1)
    }

    private func finishPlayback() {
        guard !didFinish else { return }
        didFinish = true
        player?.pause()
        onFinished()
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
