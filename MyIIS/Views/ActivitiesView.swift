//
//  ActivitiesView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct ActivitiesView: View {
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
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundStyle(.pink.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Активности")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будут ваши активности")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Активности")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ActivitiesView()
}
