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
    
    func fetchFaculties() async {
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/schedule/faculties") else { return }
        DispatchQueue.main.async { self.isLoadingFaculties = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/rating/specialities?facultyId=\\(facultyId)") else { return }
        DispatchQueue.main.async { self.isLoadingSpecialities = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/rating/courses?facultyId=20005&specialityId=\\(sdefId)") else { return }
        DispatchQueue.main.async { self.isLoadingCourses = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
        guard let url = URL(string: "https://iis.bsuir.by/api/v1/rating?sdef=\\(sdefId)&course=\\(course)") else { return }
        DispatchQueue.main.async { self.isLoadingRating = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
