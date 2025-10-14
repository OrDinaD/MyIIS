//
//  GradebookView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct GradebookView: View {
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
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Зачетка")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет ваша зачетка")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Зачетка")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    GradebookView()
}
