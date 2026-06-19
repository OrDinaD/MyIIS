import Combine
import SwiftUI

@MainActor
final class StudyWeeksService: ObservableObject {
    static let shared = StudyWeeksService()

    @Published var currentWeek: Int?
    @Published var isLoading = false

    func fetchCurrentWeek() async {
        if currentWeek == nil {
            currentWeek = fallbackWeekNumber(reference: Date())
        }

        guard let url = URL(string: "https://iis.bsuir.by/api/v1/schedule/current-week") else { return }
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let string = String(data: data, encoding: .utf8), let week = Int(string) {
                currentWeek = week
            }
        } catch {
            print("Failed to fetch current week", error)
        }
    }

    private func fallbackWeekNumber(reference: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: reference)
        let septemberFirstThisYear = calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? reference
        let academicStart = reference >= septemberFirstThisYear
            ? septemberFirstThisYear
            : (calendar.date(from: DateComponents(year: year - 1, month: 9, day: 1)) ?? reference)

        let startOfReference = calendar.startOfDay(for: reference)
        let startOfAcademic = calendar.startOfDay(for: academicStart)
        let weeks = calendar.dateComponents([.weekOfYear], from: startOfAcademic, to: startOfReference).weekOfYear ?? 0
        return max(1, weeks + 1)
    }
}

struct UnauthorizedStudyWeeksView: View {
    @StateObject private var service = StudyWeeksService.shared

    var body: some View {
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

                    Text("\(week)")
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
        .task {
            if service.currentWeek == nil {
                await service.fetchCurrentWeek()
            }
        }
    }
}
