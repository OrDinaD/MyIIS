//
//  SettingsView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct SettingsView: View {
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
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.gray.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Настройки")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будут настройки приложения")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
