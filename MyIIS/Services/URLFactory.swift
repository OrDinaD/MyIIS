import Foundation

enum URLFactory {
    static func require(_ string: String, file: StaticString = #fileID, line: UInt = #line) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid URL string: \(string)", file: file, line: line)
        }
        return url
    }
}
