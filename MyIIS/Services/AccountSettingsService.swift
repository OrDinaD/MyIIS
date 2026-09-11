//
//  AccountSettingsService.swift
//  MyIIS
//
import Foundation

final class AccountSettingsService {
    private let baseURL = URLFactory.require("https://iis.bsuir.by/api/v1")
    private let session: URLSession
    private let logService: LogService

    init(session: URLSession = .shared, logService: LogService = .shared) {
        self.session = session
        self.logService = logService
    }

    func fetchLastPasswordChange() async throws -> String? {
        let data = try await sendRequest(path: "settings/last-password-change", method: "GET")
        return parseOptionalString(data)
    }

    func fetchPasswordAttempts() async throws -> PasswordAttemptsDTO {
        let data = try await sendRequest(path: "settings/password-attempts", method: "GET")
        return try decodeJSON(PasswordAttemptsDTO.self, from: data)
    }

    func changePassword(oldPassword: String, newPassword: String) async throws {
        let body = ChangePasswordRequest(oldPassword: oldPassword, newPassword: newPassword)
        _ = try await sendRequest(path: "settings/password/change", method: "POST", jsonBody: body)
    }

    func fetchContacts() async throws -> ContactSettingsDTO {
        let data = try await sendRequest(path: "settings/contacts", method: "GET")
        return try decodeJSON(ContactSettingsDTO.self, from: data)
    }

    func updateContact(_ request: ContactUpdateRequest) async throws {
        _ = try await sendRequest(path: "settings/contact/update", method: "PUT", jsonBody: request)
    }

    func sendContactConfirmation(contactId: Int) async throws -> ContactSendConfirmResponse {
        let data = try await sendRequest(path: "settings/contact/\(contactId)/send-confirm", method: "POST")
        if data.isEmpty {
            return ContactSendConfirmResponse(codeExpirationTime: nil)
        }
        return try decodeJSON(ContactSendConfirmResponse.self, from: data)
    }

    func confirmContact(contactId: Int, code: String) async throws {
        let body = ContactConfirmRequest(contactId: contactId, code: code)
        _ = try await sendRequest(path: "settings/contact/confirm", method: "POST", jsonBody: body)
    }

    func fetchPhotoBase64() async throws -> String? {
        let data = try await sendRequest(path: "settings/photo", method: "GET")
        return parseOptionalString(data)
    }

    @discardableResult
    func changePhoto(base64: String) async throws -> String? {
        let body = ChangePhotoRequest(photoBase64String: base64)
        let data = try await sendRequest(path: "settings/change-photo", method: "PUT", jsonBody: body)
        return parseOptionalString(data)
    }

    func fetchShowPhoto() async throws -> Bool {
        let data = try await sendRequest(path: "settings/show-photo", method: "GET")
        return try parseBool(data)
    }

    func changeShowPhoto(_ showPhoto: Bool) async throws -> Bool {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("settings/change-show-photo"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "showPhoto", value: showPhoto ? "true" : "false")]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let data = try await sendRequest(url: url, method: "PATCH")
        return try parseBool(data)
    }

    private func sendRequest<T: Encodable>(
        path: String,
        method: String,
        jsonBody: T
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(jsonBody)
        return try await performRequest(request)
    }

    private func sendRequest(path: String, method: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        return try await sendRequest(url: url, method: method)
    }

    private func sendRequest(url: URL, method: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            logService.log("Settings request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "-")")
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                return data
            case 401, 403:
                throw APIError.unauthorized(
                    message: NSLocalizedString(
                        "api_error_session_expired",
                        value: "Сессия истекла. Войдите заново.",
                        comment: ""
                    )
                )
            case 418:
                throw APIError.serviceUnavailable(
                    message: NSLocalizedString(
                        "api_error_service_temporarily_unavailable",
                        value: "Сервис временно недоступен",
                        comment: ""
                    )
                )
            default:
                let serverMessage = parseServerMessage(data)
                    ?? NSLocalizedString("api_error_server", value: "Ошибка сервера", comment: "")
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: serverMessage)
            }
        } catch let apiError as APIError {
            if case .unauthorized = apiError {
                AuthenticationSessionEvents.reportUnauthorized()
            }
            throw apiError
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func parseServerMessage(_ data: Data) -> String? {
        if let value = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return value.msg
        }

        if let string = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            return string
        }
        return nil
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func parseOptionalString(_ data: Data) -> String? {
        if data.isEmpty {
            return nil
        }

        if let decodedString = try? JSONDecoder().decode(String.self, from: data),
           !decodedString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return decodedString
        }

        if let plainString = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !plainString.isEmpty {
            return plainString
        }

        return nil
    }

    private func parseBool(_ data: Data) throws -> Bool {
        if let boolValue = try? JSONDecoder().decode(Bool.self, from: data) {
            return boolValue
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            if text == "true" { return true }
            if text == "false" { return false }
        }

        throw APIError.decodingError(
            NSError(
                domain: "AccountSettingsService",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(
                        "api_error_decode_boolean",
                        value: "Не удалось декодировать Boolean-ответ",
                        comment: ""
                    )
                ]
            )
        )
    }
}
