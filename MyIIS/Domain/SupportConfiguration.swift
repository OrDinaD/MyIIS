import Foundation

struct SupportDocumentItem: Identifiable {
    var id: String { number }
    let number: String
    let title: String
    let path: String
    let url: URL
}

struct SupportDocumentGroup: Identifiable {
    var id: Int { groupNumber }
    let groupNumber: Int
    let groupName: String
    let localNetworkOnly: Bool
    let note: String?
    let items: [SupportDocumentItem]
}

struct SupportConfiguration {
    static let documentGroups: [SupportDocumentGroup] = [
        SupportDocumentGroup(
            groupNumber: 1,
            groupName: String(
                localized: "Система для организации выполнения заявок от структурных подразделений и пользователей"
            ),
            localNetworkOnly: false,
            note: nil,
            items: [
                SupportDocumentItem(
                    number: "1.1",
                    title: String(localized: "Стандартный набор ПО"),
                    path: "public_iis_files/softwareList.pdf",
                    url: URL(string: "https://iis.bsuir.by/public_iis_files/softwareList.pdf")!
                )
            ]
        ),
        SupportDocumentGroup(
            groupNumber: 2,
            groupName: String(localized: "Настройки компьютерной сети"),
            localNetworkOnly: false,
            note: nil,
            items: [
                SupportDocumentItem(
                    number: "2.1",
                    title: String(localized: "Руководство для настройки Wi‑Fi"),
                    path: "public_iis_files/wifiGuide.pdf",
                    url: URL(string: "https://iis.bsuir.by/public_iis_files/wifiGuide.pdf")!
                ),
                SupportDocumentItem(
                    number: "2.2",
                    title: String(localized: "Настройка OpenVPN"),
                    path: "public_iis_files/setupOpenVPN.pdf",
                    url: URL(string: "https://iis.bsuir.by/public_iis_files/setupOpenVPN.pdf")!
                )
            ]
        ),
        SupportDocumentGroup(
            groupNumber: 3,
            groupName: String(
                localized: "Политика безопасности в отношении обработки персональных данных БГУИР"
            ),
            localNetworkOnly: false,
            note: nil,
            items: [
                SupportDocumentItem(
                    number: "3.1",
                    title: String(localized: "Политика обработки файлов cookie"),
                    path: "public_iis_files/cookiePolicy.pdf",
                    url: URL(string: "https://iis.bsuir.by/public_iis_files/cookiePolicy.pdf")!
                ),
                SupportDocumentItem(
                    number: "3.2",
                    title: String(localized: "Инструкция по смене пароля"),
                    path: "public_iis_files/changePasswordLDAP.pdf",
                    url: URL(string: "https://iis.bsuir.by/public_iis_files/changePasswordLDAP.pdf")!
                )
            ]
        ),
        SupportDocumentGroup(
            groupNumber: 4,
            groupName: String(localized: "Политика безопасности БГУИР"),
            localNetworkOnly: true,
            note: String(localized: "Доступно только из локальной сети БГУИР"),
            items: [
                SupportDocumentItem(
                    number: "4.1",
                    title: String(localized: "Политика безопасности университета"),
                    path: "iis_files/privacyPolicy.pdf",
                    url: URL(string: "https://iis.bsuir.by/iis_files/privacyPolicy.pdf")!
                ),
                SupportDocumentItem(
                    number: "4.2",
                    title: String(localized: "Список ответственных за соблюдение политики безопасности"),
                    path: "iis_files/privacyPolicyList.pdf",
                    url: URL(string: "https://iis.bsuir.by/iis_files/privacyPolicyList.pdf")!
                ),
                SupportDocumentItem(
                    number: "4.3",
                    title: String(localized: "Инструкция по настройке ПК в структурных подразделениях"),
                    path: "iis_files/pcSettings.pdf",
                    url: URL(string: "https://iis.bsuir.by/iis_files/pcSettings.pdf")!
                )
            ]
        )
    ]
}
