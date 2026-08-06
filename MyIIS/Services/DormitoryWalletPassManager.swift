import Foundation
import PassKit

@MainActor
final class DormitoryWalletPassManager {
    static let shared = DormitoryWalletPassManager()

    private init() {}

    /// Загружает и подготавливает PKPass с локального бэкенда (пробует localhost, mDNS и IP мака в сети)
    func fetchWalletPass(for passData: DormitoryPassData, localServerURLString: String? = nil) async throws -> PKPass {
        let candidateURLs: [URL]
        if let customString = localServerURLString, let customURL = URL(string: customString) {
            candidateURLs = [customURL]
        } else {
            candidateURLs = [
                URL(string: "http://localhost:8080/api/pass")!,
                URL(string: "http://MacBook-Pro-Vlad.local:8080/api/pass")!,
                URL(string: "http://192.168.31.177:8080/api/pass")!
            ]
        }

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

        var lastError: Error?

        for url in candidateURLs {
            print("[MyIIS_DEBUG] 🛰 Запрос PKPass карточки к: \(url.absoluteString)")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 3.0
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[MyIIS_DEBUG] ❌ Неверный тип сетевого ответа")
                    continue
                }

                print("[MyIIS_DEBUG] 📥 Статус ответа сервера: \(httpResponse.statusCode), Получено байт: \(data.count)")

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw WalletPassError.serverError("Сервер ответил со статусом \(httpResponse.statusCode)")
                }

                do {
                    let pass = try PKPass(data: data)
                    print("[MyIIS_DEBUG] ✅ PKPass успешно создан и валидирован системой PassKit!")
                    return pass
                } catch {
                    print("[MyIIS_DEBUG] ❌ Ошибка валидации PKPass системным PassKit: \(error.localizedDescription)")
                    throw WalletPassError.invalidPassSignature("Сервер сгенерировал архив карт, но система iOS сообщила: \(error.localizedDescription)")
                }
            } catch {
                print("[MyIIS_DEBUG] ⚠️ Сбой подключения к \(url.host ?? ""): \(error.localizedDescription)")
                lastError = error
            }
        }

        if let lastError = lastError as? WalletPassError {
            throw lastError
        }

        throw WalletPassError.serverUnreachable("Не удалось подключиться к локальному серверу подписи на маке (проверены localhost, MacBook-Pro-Vlad.local и 192.168.31.177). Убедитесь, что телефон подключен к той же Wi-Fi сети.")
    }
}

enum WalletPassError: LocalizedError {
    case serverError(String)
    case invalidPassSignature(String)
    case serverUnreachable(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let details):
            return details
        case .invalidPassSignature(let details):
            return details
        case .serverUnreachable(let details):
            return details
        }
    }
}
