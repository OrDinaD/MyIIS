//
//  GroupView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct GroupView: View {
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
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.cyan.gradient)
                        .symbolEffect(.pulse)
                    
                    Text("Группа")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Здесь будет информация о группе")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Группа")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    GroupView()
}
