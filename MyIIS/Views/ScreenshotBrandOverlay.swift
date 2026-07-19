import SwiftUI
import UIKit

struct ScreenshotBrandOverlay: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> BrandView {
        let view = BrandView()
        view.text = text
        return view
    }

    func updateUIView(_ uiView: BrandView, context: Context) {
        uiView.text = text
        uiView.setNeedsLayout()
    }
}

// MARK: - UIKit view

extension ScreenshotBrandOverlay {
    final class BrandView: UIView {
        private let label = UILabel()

        var text: String = "" {
            didSet {
                label.text = text
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            backgroundColor = .clear
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true

            label.textAlignment = .center
            label.font = .systemFont(ofSize: 9, weight: .bold)
            label.textColor = UIColor(
                red: 0.42,
                green: 0.25,
                blue: 0.85,
                alpha: 1
            )
            label.numberOfLines = 1

            addSubview(label)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            setNeedsLayout()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            guard let window else {
                label.isHidden = true
                return
            }

            let topInset = window.safeAreaInsets.top
            let isPortrait = bounds.height > bounds.width

            /*
             Примерная эвристика:

             20–24 pt — старые iPhone без выреза
             40–54 pt — классическая чёлка
             55+ pt   — Dynamic Island

             Apple не предоставляет публичный API вида
             "устройство имеет классическую чёлку".
             */
            let hasClassicNotch =
                isPortrait &&
                topInset >= 40 &&
                topInset < 55

            label.isHidden = !hasClassicNotch

            label.frame = CGRect(
                x: 0,
                y: 6,
                width: bounds.width,
                height: 16
            )
        }
    }
}
