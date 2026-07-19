import SwiftUI

struct ScreenshotBrandOverlay: View {
    private let brandColor = Color(
        red: 0.02,
        green: 0.39,
        blue: 0.64
    )

    var body: some View {
        GeometryReader { proxy in
            if shouldShow(in: proxy) {
                brand
                    .position(
                        x: proxy.size.width / 2,
                        y: verticalPosition(for: proxy.safeAreaInsets.top)
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var brand: some View {
        HStack(spacing: 3) {
            Image("ScreenshotBrandLogo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 13, height: 13)

            Text("MyIIS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(-0.2)
        }
        .foregroundStyle(brandColor)
        .fixedSize()
    }

    private func shouldShow(in proxy: GeometryProxy) -> Bool {
        proxy.size.height > proxy.size.width &&
            proxy.safeAreaInsets.top >= 44
    }

    private func verticalPosition(for topInset: CGFloat) -> CGFloat {
        min(20, max(16, topInset * 0.35))
    }
}

#Preview("Screenshot brand") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        ScreenshotBrandOverlay()
    }
}
