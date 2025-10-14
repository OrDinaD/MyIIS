//
//  RatingView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct RatingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Рейтинг")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет ваш рейтинг")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Рейтинг")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    RatingView()
}
