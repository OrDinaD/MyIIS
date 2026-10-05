import SwiftUI

extension ScheduleServiceView {
    func scrollToTodayOrCurrent(proxy: ScrollViewProxy) {
        if let todayDay = viewModel.upcomingContinuousDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(todayDay.id, anchor: .top)
            }
        } else if let firstUpcoming = viewModel.upcomingContinuousDays.first {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(firstUpcoming.id, anchor: .top)
            }
        }
    }

    var scheduleDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = viewModel.schedule?.startDate.map(calendar.startOfDay(for:)) ?? today
        let fallbackEnd = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        let end = viewModel.schedule?.endDate.map(calendar.startOfDay(for:)) ?? fallbackEnd
        let minBound = min(today, min(start, end))
        let maxBound = max(today, max(start, end))
        return minBound ... maxBound
    }

    var usesLocalJSONSchedule: Bool {
        viewModel.dataSource == .localJSON
    }

    func loadSelectedScheduleSource() async {
        if usesLocalJSONSchedule {
            applyLocalSchedule()
        } else {
            await viewModel.loadInitialData()
        }
    }

    func applyLocalSchedule() {
        guard let document = localScheduleViewModel.document else {
            return
        }
        viewModel.applyLocalSchedule(document)
    }
}
