//
//  ScheduleServerConfiguration.swift
//  MyIIS
//

import Foundation

/// Режим выбора сервера для получения расписания и справочников.
public enum ScheduleAPIServer: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto = "auto"
    case gateway = "gateway"
    case official = "official"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .auto:
            return NSLocalizedString("server_mode_auto", value: "Авто (Шлюз + Fallback)", comment: "")
        case .gateway:
            return NSLocalizedString("server_mode_gateway", value: "Шлюз MyIIS (bsuir.ordinad.xyz)", comment: "")
        case .official:
            return NSLocalizedString("server_mode_official", value: "Официальный БГУИР (iis.bsuir.by)", comment: "")
        }
    }

    public var shortTitle: String {
        switch self {
        case .auto:
            return "Авто"
        case .gateway:
            return "Шлюз"
        case .official:
            return "БГУИР"
        }
    }

    public var iconName: String {
        switch self {
        case .auto:
            return "arrow.triangle.swap"
        case .gateway:
            return "bolt.horizontal.fill"
        case .official:
            return "building.columns.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .auto:
            return NSLocalizedString(
                "server_mode_auto_desc",
                value: "Использует быстрый Cloudflare-шлюз с автоматическим переключением на БГУИР при сбое",
                comment: ""
            )
        case .gateway:
            return NSLocalizedString(
                "server_mode_gateway_desc",
                value: "Оптимизированный Edge-сервер с Brotli-сжатием и SWR-кэшированием в оперативной памяти",
                comment: ""
            )
        case .official:
            return NSLocalizedString(
                "server_mode_official_desc",
                value: "Прямое подключение к серверу университета без промежуточных узлов",
                comment: ""
            )
        }
    }

    public var host: String {
        switch self {
        case .gateway, .auto:
            return "bsuir.ordinad.xyz"
        case .official:
            return "iis.bsuir.by"
        }
    }

    public var baseURL: URL {
        switch self {
        case .gateway, .auto:
            return URL(string: "https://bsuir.ordinad.xyz/api/v1")!
        case .official:
            return URL(string: "https://iis.bsuir.by/api/v1")!
        }
    }
}

/// Управление конфигурацией серверов API для расписания.
public enum ScheduleServerConfiguration {
    public static let serverDefaultsKey = "services.schedule.selectedServer"
    public static let serverDidChangeNotification = Notification.Name("ScheduleServerConfigurationDidChangeNotification")

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    public static var selectedServer: ScheduleAPIServer {
        get {
            guard let raw = defaults.string(forKey: serverDefaultsKey),
                  let server = ScheduleAPIServer(rawValue: raw) else {
                return .auto
            }
            return server
        }
        set {
            let previous = selectedServer
            defaults.set(newValue.rawValue, forKey: serverDefaultsKey)
            if previous != newValue {
                NotificationCenter.default.post(
                    name: serverDidChangeNotification,
                    object: nil,
                    userInfo: ["server": newValue]
                )
            }
        }
    }

    public static let gatewayBaseURL = URL(string: "https://bsuir.ordinad.xyz/api/v1")!
    public static let officialBaseURL = URL(string: "https://iis.bsuir.by/api/v1")!

    /// Определяет, поддерживается ли эндпоинт быстрым шлюзом.
    public static func isGatewaySupported(path: String) -> Bool {
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean == "schedule/current-week" ||
            clean == "student-groups" ||
            clean == "schedule" ||
            clean == "employees/all" ||
            clean.hasPrefix("employees/schedule") ||
            clean.hasPrefix("employees/photo") ||
            clean == "auditories" ||
            clean == "auditories/free" ||
            clean == "faculties" ||
            clean == "specialities" ||
            clean == "departments" ||
            clean == "widget/schedule" {
            return true
        }
        return false
    }
}
