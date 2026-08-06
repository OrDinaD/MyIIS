import Foundation
import PassKit

@MainActor
final class DormitoryWalletPassManager {
    static let shared = DormitoryWalletPassManager()

    private init() {}

    /// Загружает и подготавливает PKPass с указанного локального бэкенда или шаблона
    func fetchWalletPass(for passData: DormitoryPassData, localServerURLString: String? = nil) async throws -> PKPass {
        let serverURL: URL
        if let customString = localServerURLString, let customURL = URL(string: customString) {
            serverURL = customURL
        } else {
            // По умолчанию пробуем обратиться к локальному бэкенду на маке
            serverURL = URL(string: "http://localhost:8080/api/pass")!
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "dormitoryNumber": passData.dormitoryNumber,
            "roomNumber": passData.roomNumber,
            "lastName": passData.lastName,
            "firstName": passData.firstName,
            "middleName": passData.middleName,
            "faculty": passData.faculty,
            "group": passData.group,
            "validUntil": passData.validUntil
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw WalletPassError.serverError("Бэкенд вернул статус ответа не 200")
            }

            do {
                let pass = try PKPass(data: data)
                return pass
            } catch {
                throw WalletPassError.invalidPassData(error.localizedDescription)
            }
        } catch {
            throw WalletPassError.serverUnreachable(error.localizedDescription)
        }
    }
}

enum WalletPassError: LocalizedError {
    case serverError(String)
    case invalidPassData(String)
    case serverUnreachable(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let details):
            return "Ошибка локального сервера карт: \(details)"
        case .invalidPassData(let details):
            return "Ошибка структуры PKPass или сертификата подписи: \(details)"
        case .serverUnreachable:
            return "Локальный бэкенд подписания не запущен на http://localhost:8080."
        }
    }
}
