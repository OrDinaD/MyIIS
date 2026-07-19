import QuartzCore
import SwiftUI
import UIKit

struct DormitoryConfettiView: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context: Context) -> DormitoryConfettiEmitterView {
        let view = DormitoryConfettiEmitterView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: DormitoryConfettiEmitterView, context: Context) {
        uiView.setActive(isActive)
    }
}

@MainActor
class DormitoryConfettiEmitterView: UIView {
    override class var layerClass: AnyClass {
        CAEmitterLayer.self
    }

    private var emitterLayer: CAEmitterLayer {
        guard let layer = layer as? CAEmitterLayer else {
            preconditionFailure("DormitoryConfettiEmitterView requires CAEmitterLayer")
        }
        return layer
    }

    private var isConfigured = false

    override func layoutSubviews() {
        super.layoutSubviews()
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: -12)
        emitterLayer.emitterSize = CGSize(width: bounds.width, height: 1)
    }

    func setActive(_ isActive: Bool) {
        if !isConfigured {
            configureEmitter()
        }
        emitterLayer.birthRate = isActive ? 1 : 0
    }

    private func configureEmitter() {
        isConfigured = true
        backgroundColor = .clear

        emitterLayer.emitterShape = .line
        emitterLayer.emitterMode = .surface
        emitterLayer.renderMode = .unordered
        emitterLayer.masksToBounds = false
        emitterLayer.emitterCells = Self.confettiColors.enumerated().map { index, color in
            let cell = CAEmitterCell()
            cell.name = "confetti-\(index)"
            cell.contents = Self.confettiImage(color: color)?.cgImage
            cell.birthRate = 7
            cell.lifetime = 4.8
            cell.lifetimeRange = 1.2
            cell.velocity = 205
            cell.velocityRange = 90
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 5
            cell.yAcceleration = 250
            cell.xAcceleration = 0
            cell.spin = 3.4
            cell.spinRange = 5
            cell.scale = 0.72
            cell.scaleRange = 0.28
            return cell
        }
    }

    private static let confettiColors: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemOrange,
        .systemPink,
        .systemPurple,
        .systemYellow
    ]

    private static func confettiImage(color: UIColor) -> UIImage? {
        let size = CGSize(width: 12, height: 7)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 2
            ).fill()
            context.cgContext.setBlendMode(.sourceAtop)
        }
    }
}
