// BSUIR Additional API Reference v2.0.0
// This is a Swift-friendly API documentation file for AI context
// API Documentation: https://app.swaggerhub.com/apis/N1ghtF1re/BsuirAdditionalApi/2.0.0

// ⚠️ ⚠️ ⚠️ КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ ⚠️ ⚠️ ⚠️
// 
// ЭТА ДОКУМЕНТАЦИЯ НЕ СООТВЕТСТВУЕТ РЕАЛЬНОМУ API!
// 
// Реальные рабочие эндпоинты смотрите в:
// /API/REAL_API_ENDPOINTS.md
//
// Основные отличия:
// 1. Base URL: /api/v1 (НЕ /api/v2!)
// 2. Login: POST /auth/login (НЕ /auth!)
// 3. Auth Type: Cookie-based SESSION (НЕ JWT Token!)
// 4. Login Response: {username, fio, email, ...} (НЕТ поля token!)
// 5. Profile: GET /personal-information (НЕ /students/me!)
//
// Перед использованием любого эндпоинта из этого файла -
// сначала протестируйте его через Python!
//
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️

import Foundation

// MARK: - Base Configuration
struct APIConfig {
    static let baseURL = "https://iis.bsuir.by/api/v2"
    static let version = "2.0.0"

    // Example request format: SERVER_HOST/api/v2/METHOD_NAME?PARAM=VALUE
    // Contact: pankratiew@brakhmen.info
    // License: Apache 2.0
    // GitHub: https://github.com/N1ghtF1re/Bsuir-Additional-Api
}

// MARK: - Authentication Endpoints

/// POST /auth
/// Authenticate user and get JWT token
/// Request Body: { "username": "string", "password": "string" }
/// Response 200: { "token": "JWT_TOKEN_STRING" }
/// Response 401: Invalid credentials
/// Response 418: IIS not available and cache not found
struct AuthEndpoint {
    static let path = "/auth"
    static let method = "POST"

    struct Request: Codable {
        let username: String
        let password: String
    }

    struct Response: Codable {
        let token: String
    }
}

// MARK: - Students Endpoints

/// GET /students/{id}
/// Get student information by IIS ID
/// Response 200: Student object
/// Response 404: Student not found
/// Response 418: IIS not available
struct GetStudentEndpoint {
    static let path = "/students/{id}"
    static let method = "GET"

    struct Response: Codable {
        let id: Int
        let firstName: String
        let lastName: String
        let middleName: String
        let birthDay: String
        let photo: String?
        let summary: String?
        let rating: Int
        let education: Education
        let skills: [Skill]
        let references: [Reference]
        let settings: Settings

        struct Education: Codable {
            let faculty: String
            let course: Int
            let speciality: String
            let group: String
        }

        struct Skill: Codable {
            let id: Int
            let name: String
        }

        struct Reference: Codable {
            let id: Int
            let name: String
            let reference: String
        }

        struct Settings: Codable {
            let isPublicProfile: Bool
            let isSearchJob: Bool
            let isShowRating: Bool
        }
    }
}

/// GET /students/me
/// Get information about current authenticated user
/// Requires: JWT token in Authorization header
/// Response 200: Student object (same structure as GET /students/{id})
/// Response 401: JWT token is missed or expired
/// Response 418: IIS not available
struct GetCurrentStudentEndpoint {
    static let path = "/students/me"
    static let method = "GET"
    // Response type: GetStudentEndpoint.Response
}

/// GET /students/me/record-book
/// Get current student's record book (зачётная книжка)
/// Requires: JWT token
/// Response 200: RecordBook object
/// Response 401: JWT token is missed or expired
struct GetRecordBookEndpoint {
    static let path = "/students/me/record-book"
    static let method = "GET"

    struct Response: Codable {
        let number: String // Record book number
        let averageMark: Double
        let semesters: [Semester]
        let diploma: Diploma?

        struct Semester: Codable {
            let number: Int
            let averageMark: Double
            let marks: [Mark]

            struct Mark: Codable {
                let subject: String
                let formOfControl: String // "Экз.", "Зачёт", etc.
                let hours: Int
                let mark: String
                let date: String // Format: "DD.MM.YYYY"
                let teacher: String
                let retakesCount: Int
                let statistic: Statistic

                struct Statistic: Codable {
                    let averageMark: Double
                    let averageRetakes: Int
                }
            }
        }

        struct Diploma: Codable {
            // Structure not fully documented
        }
    }
}

/// GET /students/me/group
/// Get information about current user's group
/// Requires: JWT token
/// Response 200: Group object
struct GetGroupEndpoint {
    static let path = "/students/me/group"
    static let method = "GET"

    struct Response: Codable {
        let number: String
        let members: [Member]

        struct Member: Codable {
            let role: String // e.g., "Староста группы"
            let name: String
            let email: String
            let phone: String?
        }
    }
}

/// GET /students/me/settings
/// Get user's settings
/// Requires: JWT token
struct GetSettingsEndpoint {
    static let path = "/students/me/settings"
    static let method = "GET"

    struct Response: Codable {
        let isPublicProfile: Bool
        let isSearchJob: Bool
        let isShowRating: Bool
    }
}

/// PUT /students/me/settings
/// Update user's settings
/// Requires: JWT token
/// Request Body: Settings object
/// Response 200: Updated Settings object
struct UpdateSettingsEndpoint {
    static let path = "/students/me/settings"
    static let method = "PUT"

    struct Request: Codable {
        let isPublicProfile: Bool
        let isSearchJob: Bool
        let isShowRating: Bool
    }

    // Response type: GetSettingsEndpoint.Response
}

// MARK: - Schedule Endpoints

/// GET /schedule
/// Get schedule for group or employee
/// Query Parameters:
///   - studentGroup: String (optional) - Group number
///   - employeeId: Int (optional) - Employee IIS ID
///   - from: String (optional) - Start date (format: "YYYY-MM-DD")
///   - to: String (optional) - End date (format: "YYYY-MM-DD")
/// Response 200: Array of Schedule objects
/// Response 400: Invalid parameters
/// Response 418: IIS not available
struct GetScheduleEndpoint {
    static let path = "/schedule"
    static let method = "GET"

    struct Response: Codable {
        let type: String // "LESSON_LECTURE", "LESSON_PRACTICE", "EXAM", etc.
        let floor: Int
        let building: Int
        let name: String // Room number/name
    }
}

// MARK: - Auditoriums Endpoints

/// POST /auditoriums/search
/// Search for auditoriums (classrooms)
/// Request Body: Search parameters
/// Response 200: Array of Auditorium objects
struct SearchAuditoriumsEndpoint {
    static let path = "/auditoriums/search"
    static let method = "POST"

    struct Request: Codable {
        let building: Int?
        let floor: Int?
        let auditoryType: String? // "LESSON_LECTURE", "LESSON_PRACTICE", etc.
    }

    struct Response: Codable {
        let type: String
        let floor: Int
        let building: Int
        let name: String
    }
}

// MARK: - Buildings Endpoints

/// GET /buildings
/// Get list of BSUIR buildings
/// Response 200: Array of Building objects
struct GetBuildingsEndpoint {
    static let path = "/buildings"
    static let method = "GET"

    struct Response: Codable {
        let name: Int // Building number
        let floor: [Int] // Array of floor numbers
    }
}

// MARK: - News Endpoints

/// GET /news/{id}
/// Get news by ID
/// Response 200: News object
/// Response 404: News not found
struct GetNewsEndpoint {
    static let path = "/news/{id}"
    static let method = "GET"

    struct Response: Codable {
        let id: Int
        let title: String
        let source: Source
        let shortContent: String
        let content: String
        let publishedAt: String // Format: "YYYY-MM-DD HH:MM"
        let loadedAt: String
        let url: String
        let urlToImage: String?

        struct Source: Codable {
            let id: Int
            let alias: String // e.g., "FKSIS_VK"
            let type: String // e.g., "ФКСИС"
            let name: String // e.g., "Группа ВК ФКСИС"
        }
    }
}

/// POST /news
/// Add new news
/// Requires: JWT token + special permissions
/// Request Body: News object
/// Response 201: Created news object
/// Response 400: Invalid JSON
/// Response 403: Unauthorized
struct AddNewsEndpoint {
    static let path = "/news"
    static let method = "POST"
    // Structure similar to GetNewsEndpoint.Response
}

/// POST /news/search
/// Search news (to just see the list - send empty json {})
/// Request Body: Search parameters
/// Response 200: Paginated news list
struct SearchNewsEndpoint {
    static let path = "/news/search"
    static let method = "POST"

    struct Request: Codable {
        let page: Int?
        let pageSize: Int?
        let sort: Sort?
        let filters: [Filter]?

        struct Sort: Codable {
            let field: String // e.g., "id", "publishedAt"
            let type: String // "ASC" or "DESC"
        }

        struct Filter: Codable {
            let type: String // "numeric", "string", "date"
            let comparison: String // "EQ", "GT", "LT", "CONTAINS", etc.
            let value: String
            let field: String
        }
    }

    struct Response: Codable {
        let totalPages: Int
        let totalElements: Int
        let page: Int
        let pageSize: Int
        let content: [NewsItem]

        struct NewsItem: Codable {
            let id: Int
            let title: String
            let source: GetNewsEndpoint.Response.Source
            let shortContent: String
            let publishedAt: String
            let loadedAt: String
            let url: String
            let urlToImage: String?
        }
    }
}

// MARK: - News Sources Endpoints

/// GET /news/sources
/// Get all news sources
/// Response 200: Array of Source objects
struct GetNewsSourcesEndpoint {
    static let path = "/news/sources"
    static let method = "GET"

    struct Response: Codable {
        let id: Int
        let alias: String
        let type: String
        let name: String
    }
}

/// GET /news/sources/subscriptions
/// Get aliases of sources which user subscribed to
/// Requires: JWT token
/// Response 200: Array of alias strings
struct GetSubscriptionsEndpoint {
    static let path = "/news/sources/subscriptions"
    static let method = "GET"
    // Response: [String] - array of source aliases
}

/// PUT /news/sources/subscriptions
/// Change subscribed sources list
/// Requires: JWT token
/// Request Body: { "newsSourcesAliases": ["FKSIS_VK", ...] }
/// Response 200: Success
struct UpdateSubscriptionsEndpoint {
    static let path = "/news/sources/subscriptions"
    static let method = "PUT"

    struct Request: Codable {
        let newsSourcesAliases: [String]
    }
}

// MARK: - Files Endpoints

/// GET /files/size
/// Get max file size limit
/// Requires: JWT token
/// Response 200: { "maxSize": 20971520 } (bytes)
struct GetFileSizeLimitEndpoint {
    static let path = "/files/size"
    static let method = "GET"

    struct Response: Codable {
        let maxSize: Int // Max file size in bytes
    }
}

/// GET /files/{id}/download
/// Download the file
/// Requires: JWT token
/// Response 200: File binary data
/// Response 400: Invalid arguments
/// Response 401: JWT token is missed or expired
/// Response 403: No right to perform this action
/// Response 404: File not found
struct DownloadFileEndpoint {
    static let path = "/files/{id}/download"
    static let method = "GET"
}

/// GET /files/{id}
/// Get information about file by id
/// Requires: JWT token
/// Response 200: File object
struct GetFileEndpoint {
    static let path = "/files/{id}"
    static let method = "GET"

    struct Response: Codable {
        let type: String // "FILE", "DIRECTORY", "LINK"
        let id: Int
        let studentIisId: Int
        let studentName: String
        let fileName: String
        let accessType: String // "PRIVATE", "GROUP", "PUBLIC"
        let groupOwner: String?
        let mimeType: String?
        let parentFileId: Int?
        let link: String?
    }
}

/// DELETE /files/{id}
/// Delete file
/// Requires: JWT token
/// Response 200: Deleted file object
struct DeleteFileEndpoint {
    static let path = "/files/{id}"
    static let method = "DELETE"
    // Response type: GetFileEndpoint.Response
}

/// PATCH /files/{id}
/// Update file (name, access, parent directory)
/// Access updating will update all children files and directories
/// Requires: JWT token
/// Request Body: Update parameters
/// Response 200: Updated file object
struct UpdateFileEndpoint {
    static let path = "/files/{id}"
    static let method = "PATCH"

    struct Request: Codable {
        let accessType: String? // "PRIVATE", "GROUP", "PUBLIC"
        let fileName: String?
        let parentId: Int?
    }

    // Response type: GetFileEndpoint.Response
}

/// GET /directories/root/files
/// Get files in the root directory
/// Requires: JWT token
/// Response 200: Array of file objects
struct GetRootFilesEndpoint {
    static let path = "/directories/root/files"
    static let method = "GET"
    // Response: [GetFileEndpoint.Response]
}

/// GET /directories/{id}/files
/// Get files in specific directory
/// Requires: JWT token
/// Response 200: Array of file objects
struct GetDirectoryFilesEndpoint {
    static let path = "/directories/{id}/files"
    static let method = "GET"
    // Response: [GetFileEndpoint.Response]
}

/// POST /directories/{id}/file
/// Upload a file to specific directory
/// Requires: JWT token
/// Request: multipart/form-data with file
/// Query Parameter: accessType (PRIVATE, GROUP, PUBLIC)
/// Response 200: Uploaded file object
/// Response 413: File too large
struct UploadFileToDirectoryEndpoint {
    static let path = "/directories/{id}/file"
    static let method = "POST"
    // Response type: GetFileEndpoint.Response
}

/// POST /directories/root/file
/// Upload a file to root directory
/// Requires: JWT token
/// Request: multipart/form-data with file
/// Query Parameter: accessType (PRIVATE, GROUP, PUBLIC)
/// Response 200: Uploaded file object
struct UploadFileToRootEndpoint {
    static let path = "/directories/root/file"
    static let method = "POST"
    // Response type: GetFileEndpoint.Response
}

/// POST /directories/{id}/directory
/// Create subdirectory in specific directory
/// Requires: JWT token
/// Request Body: { "fileName": "string" }
/// Response 200: Created directory object
struct CreateSubdirectoryEndpoint {
    static let path = "/directories/{id}/directory"
    static let method = "POST"

    struct Request: Codable {
        let fileName: String
    }

    struct Response: Codable {
        let fileType: String // "DIRECTORY"
        let id: Int
        let userId: Int
        let fileName: String
        let accessType: String
        let ownedGroup: Int?
        let files: [GetFileEndpoint.Response]
    }
}

/// POST /directories/root/directory
/// Create directory in root
/// Requires: JWT token
/// Request Body: { "fileName": "string" }
/// Response 200: Created directory object
struct CreateRootDirectoryEndpoint {
    static let path = "/directories/root/directory"
    static let method = "POST"
    // Request/Response same as CreateSubdirectoryEndpoint
}

/// POST /directories/{id}/link
/// Create link in specific directory
/// Requires: JWT token
/// Request Body: { "fileName": "string", "url": "string" }
/// Response 200: Created link object
struct CreateLinkInDirectoryEndpoint {
    static let path = "/directories/{id}/link"
    static let method = "POST"

    struct Request: Codable {
        let fileName: String
        let url: String
    }

    struct Response: Codable {
        let fileType: String // "LINK"
        let id: Int
        let userId: Int
        let fileName: String
        let url: String
        let accessType: String
        let ownedGroup: String?
    }
}

/// POST /directories/root/link
/// Create link in root directory
/// Requires: JWT token
/// Request Body: { "fileName": "string", "url": "string" }
/// Response 200: Created link object
struct CreateLinkInRootEndpoint {
    static let path = "/directories/root/link"
    static let method = "POST"
    // Request/Response same as CreateLinkInDirectoryEndpoint
}

// MARK: - Faculty & Specialities Endpoints

/// GET /faculties-specialities
/// Get all faculties and their specialities
/// Requires: JWT token
/// Response 200: Array of Faculty objects
struct GetFacultiesEndpoint {
    static let path = "/faculties-specialities"
    static let method = "GET"

    struct Response: Codable {
        let name: String
        let alias: String // e.g., "КСиС"
        let specialities: [Speciality]

        struct Speciality: Codable {
            let name: String
            let alias: String // e.g., "ПИ", "ПОИТ"
            let educationForm: String // "FULL_TIME", "EXTRAMURAL", etc.
        }
    }
}

// MARK: - Rating Endpoints

/// GET /rating
/// Get students rating by group
/// Requires: JWT token
/// Query Parameter: group (required) - group number
/// Response 200: Array of student rating objects
struct GetRatingEndpoint {
    static let path = "/rating"
    static let method = "GET"

    struct Response: Codable {
        let recordBookNumber: String
        let averageGrade: Double
        let missedHours: Int
        let averageShift: Double
        let checkPoint: [CheckPoint]

        struct CheckPoint: Codable {
            let number: Int
            let averageGrade: Double
            let missedHours: Int
        }
    }
}

// MARK: - Push Notifications Endpoints

/// POST /push-notifications
/// Register push notification token
/// Requires: JWT token
/// Request Body: { "token": "string", "tokenType": "APPLE_TOKEN" or "GOOGLE_TOKEN" }
/// Response 200: Success
struct RegisterPushTokenEndpoint {
    static let path = "/push-notifications"
    static let method = "POST"

    struct Request: Codable {
        let token: String
        let tokenType: String // "APPLE_TOKEN" or "GOOGLE_TOKEN"
    }
}

/// DELETE /push-notifications/{token}
/// Delete push notification token
/// Requires: JWT token
/// Response 200: Success
struct DeletePushTokenEndpoint {
    static let path = "/push-notifications/{token}"
    static let method = "DELETE"
}

/// POST /push-notifications/test
/// Send test push notification to current user
/// Requires: JWT token
/// Response 200: Success
struct SendTestPushEndpoint {
    static let path = "/push-notifications/test"
    static let method = "POST"
}

// MARK: - Common Error Responses

struct ErrorResponse: Codable {
    let msg: String
}

// Common HTTP status codes:
// 200 - Success
// 201 - Created
// 400 - Invalid arguments/parameters
// 401 - JWT token is missed or expired / Invalid credentials
// 403 - Unauthorized (user has no right to perform this action)
// 404 - Entity not found
// 413 - Payload too large (file too big)
// 418 - IIS is not available and cache is not found (classic teapot error!)

// MARK: - Authentication Helper

/// Helper for Authorization header
/// All protected endpoints require: Authorization: Bearer {JWT_TOKEN}
struct AuthorizationHeader {
    static func bearer(_ token: String) -> [String: String] {
        return ["Authorization": "Bearer \(token)"]
    }
}

// MARK: - Usage Examples

/*
 // 1. Authentication
 let authRequest = AuthEndpoint.Request(username: "12345678", password: "password")
 // POST to /auth with authRequest
 // Receive: AuthEndpoint.Response with token
 
 // 2. Get current user info
 // GET to /students/me with Authorization header
 // Receive: GetStudentEndpoint.Response
 
 // 3. Get record book
 // GET to /students/me/record-book with Authorization header
 // Receive: GetRecordBookEndpoint.Response
 
 // 4. Search news
 let newsSearch = SearchNewsEndpoint.Request(
     page: 0,
     pageSize: 10,
     sort: .init(field: "publishedAt", type: "DESC"),
     filters: nil
 )
 // POST to /news/search with newsSearch
 // Receive: SearchNewsEndpoint.Response
 
 // 5. Get schedule
 // GET to /schedule?studentGroup=751006&from=2024-01-01&to=2024-01-31
 // Receive: [GetScheduleEndpoint.Response]
 */
