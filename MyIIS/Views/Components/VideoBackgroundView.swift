//
//  VideoBackgroundView.swift
//  MyIIS
//
//  Created by Codex on 02.02.26.
//

import SwiftUI
import AVFoundation

/// Looping video background that uses an AVQueuePlayer configured for silent playback.
struct VideoBackgroundView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        view.configure(with: resourceName, fileExtension: resourceExtension)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {
        uiView.configure(with: resourceName, fileExtension: resourceExtension)
    }
}

final class LoopingPlayerView: UIView {
    private let queuePlayer = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private var currentResourceIdentifier: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        queuePlayer.isMuted = true
        queuePlayer.allowsExternalPlayback = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func configure(with resource: String, fileExtension: String) {
        let identifier = "\(resource).\(fileExtension)"
        guard identifier != currentResourceIdentifier else {
            if queuePlayer.timeControlStatus != .playing {
                queuePlayer.play()
            }
            return
        }

        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
            assertionFailure("Missing video resource \(identifier)")
            return
        }

        queuePlayer.pause()
        queuePlayer.removeAllItems()

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        queuePlayer.play()
        currentResourceIdentifier = identifier
    }
}
