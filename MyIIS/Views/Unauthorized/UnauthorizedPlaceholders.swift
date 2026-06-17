import SwiftUI







struct UnauthorizedDisciplinesView: View {
    var body: some View {
        ContentUnavailableView("Список дисциплин", systemImage: "list.bullet.rectangle.portrait", description: Text("В разработке (Итерация 6)"))
            .navigationTitle("Дисциплины")
    }
}

struct UnauthorizedStudyWeeksView: View {
    var body: some View {
        ContentUnavailableView("Учебные недели", systemImage: "calendar.day.timeline.left", description: Text("В разработке (Итерация 7)"))
            .navigationTitle("Учебные недели")
    }
}