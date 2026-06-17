import SwiftUI









struct UnauthorizedStudyWeeksView: View {
    var body: some View {
        ContentUnavailableView("Учебные недели", systemImage: "calendar.day.timeline.left", description: Text("В разработке (Итерация 7)"))
            .navigationTitle("Учебные недели")
    }
}