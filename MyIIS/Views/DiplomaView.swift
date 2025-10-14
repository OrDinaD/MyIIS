//
//  DiplomaView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct DiplomaView: View {
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
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.teal.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Диплом")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет информация о дипломе")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Диплом")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    DiplomaView()
}
