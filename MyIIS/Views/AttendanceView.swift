//
//  AttendanceView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct AttendanceView: View {
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
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 80))
                        .foregroundStyle(.orange.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Пропуски")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будут ваши пропуски")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Пропуски")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    AttendanceView()
}
