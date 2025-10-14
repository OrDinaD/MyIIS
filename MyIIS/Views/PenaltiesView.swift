//
//  PenaltiesView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct PenaltiesView: View {
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
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.yellow.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Взыскания")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будут ваши взыскания")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Взыскания")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    PenaltiesView()
}
