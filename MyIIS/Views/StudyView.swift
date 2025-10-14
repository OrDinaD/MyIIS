//
//  StudyView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct StudyView: View {
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
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.indigo.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Учеба")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет информация об учебе")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Учеба")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    StudyView()
}
