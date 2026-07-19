import SwiftUI
import UIKit

struct ScreenshotBrandOverlay: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> ViewExtractor {
        let view = ViewExtractor()
        view.text = text
        return view
    }

    func updateUIView(_ uiView: ViewExtractor, context: Context) {
        uiView.text = text
    }

    // Эта скрытая UIView нужна только для того, чтобы получить доступ
    // к текущему UIWindowScene и прикрепить поверх него новый плавающий UIWindow.
    final class ViewExtractor: UIView {
        var text: String = "" {
            didSet {
                overlayWindow?.text = text
            }
        }
        private var overlayWindow: BrandOverlayWindow?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.isHidden = true
            self.isUserInteractionEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window = self.window, let scene = window.windowScene else { return }
            
            if overlayWindow == nil {
                let overlay = BrandOverlayWindow(windowScene: scene)
                overlay.text = text
                overlay.isHidden = false
                overlayWindow = overlay
            }
        }
    }
}

// MARK: - Floating UIWindow

final class BrandOverlayWindow: UIWindow {
    private let label = UILabel()

    var text: String = "" {
        didSet {
            label.text = text
        }
    }

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)

        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        // Делаем окно поверх всего (включая шторки, алерты и навигацию)
        self.windowLevel = .init(rawValue: 1000)

        label.textAlignment = .center
        label.font = .systemFont(ofSize: 10, weight: .bold)
        // Фирменный фиолетовый цвет, но с небольшой тенью на случай светлого фона под чёлкой на скриншоте
        label.textColor = UIColor(red: 0.42, green: 0.25, blue: 0.85, alpha: 1)
        label.layer.shadowColor = UIColor.white.cgColor
        label.layer.shadowOffset = .zero
        label.layer.shadowOpacity = 0.5
        label.layer.shadowRadius = 1
        label.numberOfLines = 1

        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let topInset = safeAreaInsets.top
        let isPortrait = bounds.height > bounds.width

        let hasClassicNotch =
            isPortrait &&
            topInset >= 40 &&
            topInset < 55

        label.isHidden = !hasClassicNotch

        label.frame = CGRect(
            x: 0,
            y: 14,
            width: bounds.width,
            height: 16
        )
    }
}
