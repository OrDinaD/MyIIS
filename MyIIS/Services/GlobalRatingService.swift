import Foundation
import Combine

class GlobalRatingService: ObservableObject {
    static let shared = GlobalRatingService()
    
    @Published var faculties: [FacultyDto] = []
    @Published var specialities: [SpecialityDto] = []
    @Published var courses: [Int] = []
    @Published var ratingEntries: [GlobalRatingEntry] = []
    
    @Published var isLoadingFaculties = false
    @Published var isLoadingSpecialities = false
    @Published var isLoadingCourses = false
    @Published var isLoadingRating = false
    
    private init() {}
    
    private func mockData(for urlString: String, from jsonString: String) throws -> Data {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json[urlString] else {
            throw URLError(.fileDoesNotExist)
        }
        return try JSONSerialization.data(withJSONObject: value)
    }
    
    func fetchFaculties() async {
        DispatchQueue.main.async { self.isLoadingFaculties = true }
        do {
            let data = try mockData(for: "https://iis.bsuir.by/api/v1/schedule/faculties", from: AppMockData.ratingMockJSON)
            let decoder = JSONDecoder()
            let response = try decoder.decode([FacultyDto].self, from: data)
            DispatchQueue.main.async {
                self.faculties = response
                self.isLoadingFaculties = false
            }
        } catch {
            print("Failed to fetch faculties", error)
            DispatchQueue.main.async { self.isLoadingFaculties = false }
        }
    }
    
    func fetchSpecialities(facultyId: Int) async {
        DispatchQueue.main.async { self.isLoadingSpecialities = true }
        do {
            let data = try mockData(for: "https://iis.bsuir.by/api/v1/rating/specialities?facultyId=\\(facultyId)", from: AppMockData.ratingMockJSON)
            let decoder = JSONDecoder()
            let response = try decoder.decode([SpecialityDto].self, from: data)
            DispatchQueue.main.async {
                self.specialities = response
                self.isLoadingSpecialities = false
            }
        } catch {
            print("Failed to fetch specialities", error)
            DispatchQueue.main.async { self.isLoadingSpecialities = false }
        }
    }
    
    func fetchCourses(sdefId: Int) async {
        // Mock data keys use facultyId and specialityId... let's just pick any or extract it.
        // Wait, the mock data key is "https://iis.bsuir.by/api/v1/rating/courses?facultyId=20005&specialityId=20835"
        // But our UI passes `sdefId` (which is `specialityId`). We can just find the key that ends with `specialityId=\(sdefId)`.
        DispatchQueue.main.async { self.isLoadingCourses = true }
        do {
            guard let dataStr = AppMockData.ratingMockJSON.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: dataStr) as? [String: Any],
                  let key = json.keys.first(where: { $0.contains("specialityId=\\(sdefId)") }),
                  let value = json[key] else {
                throw URLError(.fileDoesNotExist)
            }
            let data = try JSONSerialization.data(withJSONObject: value)
            
            let decoder = JSONDecoder()
            let response = try decoder.decode([Int].self, from: data)
            DispatchQueue.main.async {
                self.courses = response.sorted()
                self.isLoadingCourses = false
            }
        } catch {
            print("Failed to fetch courses", error)
            DispatchQueue.main.async { self.isLoadingCourses = false }
        }
    }
    
    func fetchRating(sdefId: Int, course: Int) async {
        DispatchQueue.main.async { self.isLoadingRating = true }
        do {
            let data = try mockData(for: "https://iis.bsuir.by/api/v1/rating?sdef=\\(sdefId)&course=\\(course)", from: AppMockData.ratingMockJSON)
            let decoder = JSONDecoder()
            let response = try decoder.decode([GlobalRatingEntry].self, from: data)
            DispatchQueue.main.async {
                self.ratingEntries = response.sorted { ($0.average ?? 0) > ($1.average ?? 0) }
                self.isLoadingRating = false
            }
        } catch {
            print("Failed to fetch rating", error)
            DispatchQueue.main.async { self.isLoadingRating = false }
        }
    }
}
