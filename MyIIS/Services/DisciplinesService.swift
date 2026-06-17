import Foundation
import Combine

class DisciplinesService: ObservableObject {
    static let shared = DisciplinesService()
    
    @Published var disciplines: [DisciplineListEntry] = []
    @Published var isLoading = false
    
    // We can reuse GlobalRatingService for faculties/specialities/courses to save code!
    
    func fetchDisciplines(sdefId: Int, course: Int, term: Int?) async {
        var urlStr = "https://iis.bsuir.by/api/v1/list-disciplines?id=\\(sdefId)&course=\\(course)&isForeign=false"
        if let term = term {
            urlStr += "&term=\\(term)"
        }
        
        guard let url = URL(string: urlStr) else { return }
        
        DispatchQueue.main.async { self.isLoading = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode([DisciplineListEntry].self, from: data)
            DispatchQueue.main.async {
                self.disciplines = response
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch disciplines", error)
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
}
