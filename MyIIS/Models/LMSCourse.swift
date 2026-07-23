import Foundation

struct LMSCourse: Identifiable, Codable {
    let id: Int
    let name: String
    let teachers: [String]
    let backgroundUrl: URL?

    var teachersString: String {
        teachers.joined(separator: ", ")
    }
}

struct LMSCourseDetail: Codable {
    let id: Int
    let fullname: String
    let sections: [LMSSection]
}

struct LMSSection: Identifiable, Codable {
    var id: String { name + "\(modules.count)" }
    let name: String
    let modules: [LMSModule]
}

struct LMSModule: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let type: LMSModuleType
    let url: URL?
    let indent: Int

    enum LMSModuleType: String, Codable {
        case resource // File (PDF, etc)
        case assign // Assignment
        case quiz // Test
        case forum // Forum
        case page // Moodle page
        case label // Text label
        case folder // Folder
        case url // Link
        case feedback // Poll/Feedback
        case choice // Choice/Poll
        case survey // Survey
        case unknown

        var icon: String {
            switch self {
            case .resource: return "doc.fill"
            case .assign: return "doc.text.badge.plus"
            case .quiz: return "checkmark.seal.fill"
            case .forum: return "bubble.left.and.bubble.right.fill"
            case .page: return "doc.text.fill"
            case .label: return "info.circle"
            case .folder: return "folder.fill"
            case .url: return "link"
            case .feedback, .survey, .choice: return "checklist"
            case .unknown: return "questionmark.circle"
            }
        }
    }
}
