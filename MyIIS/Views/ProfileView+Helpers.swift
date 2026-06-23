import SwiftUI

extension ProfileView {
    func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    func formattedFullName(_ user: User) -> String {
        let parts = [user.lastName, user.firstName, user.middleName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard parts.count == 3 else {
            return parts.joined(separator: " ")
        }

        // Фамилия остаётся на первой строке, имя и отчество переносятся ниже при необходимости.
        return "\(parts[0])\n\(parts[1]) \(parts[2])"
    }

    func formattedBelarusianFullName(_ user: User) -> String? {
        let parts = [user.belarusianLastName, user.belarusianFirstName, user.belarusianMiddleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    func getIconForReference(_ name: String) -> String {
        switch name.lowercased() {
        case "vk", "vkontakte":
            return "person.2.fill"
        case "telegram", "tg":
            return "paperplane.fill"
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "linkedin":
            return "briefcase.fill"
        case "instagram":
            return "camera.fill"
        default:
            return "link"
        }
    }
}
