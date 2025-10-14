//
//  DormitoryView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct DormitoryView: View {
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
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.mint.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Общежитие")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет информация об общежитии")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Общежитие")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    DormitoryView()
}
