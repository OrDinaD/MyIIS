import Foundation

struct SupportConfiguration {
    static func getFields(for categoryKey: String) -> [SupportField] {
        switch categoryKey {
        case "[ИИС]", "[СТУДЕНТЫ]":
            return [.description]
        case "[PC-Software]":
            return [.phone, .department, .roomBuilding, .computerName, .inventoryNumber, .description]
        case "[Network-Account]":
            return [.phone, .department, .description]
        case "[Print]":
            return [.phone, .department, .roomBuilding, .computerName, .printerName, .inventoryNumber, .description]
        case "[Network]":
            return [.phone, .department, .roomBuilding, .computerName, .description]
        case "[ActEquip]":
            return [.acts, .description]
        case "[LMS]", "[UMU]", "[Other]":
            return [.phone, .description]
        case "[SMB]":
            return [.phone, .department, .roomBuilding, .computerName, .description]
        case "[ID-Card]":
            return [.description, .phone]
        default:
            return [.description]
        }
    }
    
    static func getNotices(for categoryKey: String) -> [String] {
        switch categoryKey {
        case "[PC-Software]":
            return [
                "В соответствии с положением о ЦИИР, в отношении кафедр оказываются только услуги по ремонту техники. По остальным вопросам обращаться к инженерам кафедры.",
                "При необходимости приобретения запасных частей для ремонта компьютерной техники необходимо написать докладную записку на имя курирующего проректора."
            ]
        case "[Print]":
            return [
                "При необходимости приобретения запасных частей для ремонта компьютерной техники необходимо написать докладную записку на имя курирующего проректора.",
                "По вопросу замены картриджей обращайтесь в отдел снабжения."
            ]
        default:
            return []
        }
    }
    
    static let documentGroups: [SupportDocumentGroup] = [
        SupportDocumentGroup(
            groupNumber: 1,
            groupName: "Система для организации выполнения заявок от структурных подразделений и пользователей",
            localNetworkOnly: false,
            note: nil,
            items: [
                SupportDocumentItem(number: "1.1", title: "Стандартный набор ПО", path: "public_iis_files/softwareList.pdf", url: URL(string: "https://iis.bsuir.by/public_iis_files/softwareList.pdf")!)
            ]
        ),
        SupportDocumentGroup(
            groupNumber: 2,
            groupName: "Настройки компьютерной сети",
            localNetworkOnly: false,
            note: nil,
            items: [
                SupportDocumentItem(number: "2.1", title: "Руководство для настройки Wi‑Fi", path: "public_iis_files/wifiGuide.pdf", url: URL(string: "https://iis.bsuir.by/public_iis_files/wifiGuide.pdf")!),
                SupportDocumentItem(number: "2.2", title: "Настройка OpenVPN", path: "public_iis_files/setupOpenVPN.pdf", url: URL(string: "https://iis.bsuir.by/public_iis_files/setupOpenVPN.pdf")!)
            ]
        ),
        SupportDocumentGroup(
            groupNumber: 3,
            groupName: "Политика безопасности в отношении обработки персональных данных БГУИР",
            localNetworkOnly: false,
            note: nil,
            items: [
                SupportDocumentItem(number: "3.1", title: "Политика обработки файлов cookie", path: "public_iis_files/cookiePolicy.pdf", url: URL(string: "https://iis.bsuir.by/public_iis_files/cookiePolicy.pdf")!),
                SupportDocumentItem(number: "3.2", title: "Инструкция по смене пароля", path: "public_iis_files/changePasswordLDAP.pdf", url: URL(string: "https://iis.bsuir.by/public_iis_files/changePasswordLDAP.pdf")!)
            ]
        ),
        SupportDocumentGroup(
            groupNumber: 4,
            groupName: "Политика безопасности БГУИР",
            localNetworkOnly: true,
            note: "Доступно только из локальной сети БГУИР",
            items: [
                SupportDocumentItem(number: "4.1", title: "Политика безопасности университета", path: "iis_files/privacyPolicy.pdf", url: URL(string: "https://iis.bsuir.by/iis_files/privacyPolicy.pdf")!),
                SupportDocumentItem(number: "4.2", title: "Список ответственных за соблюдение политики безопасности", path: "iis_files/privacyPolicyList.pdf", url: URL(string: "https://iis.bsuir.by/iis_files/privacyPolicyList.pdf")!),
                SupportDocumentItem(number: "4.3", title: "Инструкция по настройке ПК в структурных подразделениях", path: "iis_files/pcSettings.pdf", url: URL(string: "https://iis.bsuir.by/iis_files/pcSettings.pdf")!)
            ]
        )
    ]
}
