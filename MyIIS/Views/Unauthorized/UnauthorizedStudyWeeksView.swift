import SwiftUI
import Combine

class StudyWeeksService: ObservableObject {
    static let shared = StudyWeeksService()
    
    @Published var currentWeek: Int?
    @Published var isLoading = false
    
    func fetchCurrentWeek() async {
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/schedule/current-week") else { return }
        DispatchQueue.main.async { self.isLoading = true }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let string = String(data: data, encoding: .utf8), let week = Int(string) {
                DispatchQueue.main.async {
                    self.currentWeek = week
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async { self.isLoading = false }
            }
        } catch {
            print("Failed to fetch current week", error)
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
}

struct UnauthorizedStudyWeeksView: View {
    @StateObject private var service = StudyWeeksService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                if service.isLoading && service.currentWeek == nil {
                    ProgressView("Определение учебной недели...")
                } else if let week = service.currentWeek {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                        
                        Text("Текущая учебная неделя")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Text("\\(week)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                        
                        Text("по расписанию БГУИР")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(40)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        "Не удалось загрузить",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Невозможно определить текущую учебную неделю. Проверьте подключение к сети.")
                    )
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Учебные недели")
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .hiddenNavigationBarBackground()
            .onAppear {
                if service.currentWeek == nil {
                    Task { await service.fetchCurrentWeek() }
                }
            }
        }
    }
}
