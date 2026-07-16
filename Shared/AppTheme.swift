//
//  AppTheme.swift
//  MyIIS
//
import SwiftUI

@MainActor
enum AppTheme {
    static func configureAppearances() {
#if os(iOS)
        configureNavigationBars()
        configureTablesAndCollections()
#endif
    }

#if os(iOS)
    private static func configureNavigationBars() {
        // Starting with iOS 26, SwiftUI and UIKit provide the system Liquid Glass
        // appearance. Avoid overriding it globally so future system refinements,
        // including iOS 27, apply automatically.
        guard #unavailable(iOS 26.0) else { return }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color.black.opacity(0.55))
                : UIColor(Color.white.opacity(0.75))
        }
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private static func configureTablesAndCollections() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }
#endif
}
