//
//  AppTheme.swift
//  MyIIS
//
//  Created by OpenAI Assistant on 11.03.2026.
//

import SwiftUI

enum AppTheme {
    static func configureAppearances() {
#if os(iOS)
        configureNavigationBars()
        configureTablesAndCollections()
#endif
    }

#if os(iOS)
    private static func configureNavigationBars() {
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
