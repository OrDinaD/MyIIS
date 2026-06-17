import Foundation
import Combine

class DisciplinesService: ObservableObject {
    static let shared = DisciplinesService()
    
    @Published var disciplines: [DisciplineListEntry] = []
    @Published var isLoading = false
    
    // We can reuse GlobalRatingService for faculties/specialities/courses to save code!
    
    private func mockData(for urlString: String, from jsonString: String) throws -> Data {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json[urlString] else {
            throw URLError(.fileDoesNotExist)
        }
        return try JSONSerialization.data(withJSONObject: value)
    }
    
    func fetchDisciplines(sdefId: Int, course: Int, term: Int?) async {
        var urlStr = "https://iis.bsuir.by/api/v1/list-disciplines?id=\\(sdefId)&course=\\(course)&isForeign=false"
        if let term = term {
            urlStr += "&term=\\(term)"
        }
        
        DispatchQueue.main.async { self.isLoading = true }
        do {
            let data = try mockData(for: urlStr, from: AppMockData.disciplinesMockJSON)
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
