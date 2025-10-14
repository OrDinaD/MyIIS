//
//  AnnouncementsView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct AnnouncementsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
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
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Объявления")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будут объявления")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Объявления")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    AnnouncementsView()
}
