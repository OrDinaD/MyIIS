import Foundation
import Combine
import SwiftUI

class PhoneBookService: ObservableObject {
    static let shared = PhoneBookService()
    
    @Published var entries: [PhoneBookEntry] = []
    @Published var isLoading = false
    
    private let url = URL(string: "https://iis.bsuir.by/api/v1/phone-book")!
    
    func search(query: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "searchValue": query,
            "currentPage": 1,
            "pageSize": 50 // Load more to avoid pagination for now
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let response = try decoder.decode(PhoneBookResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.entries = response.auditoryPhoneNumberDtoList
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch phone book: \\(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}
