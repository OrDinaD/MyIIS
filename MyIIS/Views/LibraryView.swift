//
//  LibraryView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct LibraryView: View {
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
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.brown.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Библиотека")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет библиотека")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Библиотека")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    LibraryView()
}
