//
//  MyIISApp.swift
//  MyIIS
//
//  Created by Влад on 13.10.25.
//

import SwiftUI

@main
struct MyIISApp: App {
    /// Создаем и удерживаем экземпляр сервиса аутентификации
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService) // Внедряем его в окружение
        }
    }
}