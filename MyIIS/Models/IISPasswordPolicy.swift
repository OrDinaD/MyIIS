import Foundation

enum IISPasswordPolicy {
    static func isValid(_ password: String, login: String) -> Bool {
        guard (8...30).contains(password.count) else { return false }
        let hasLower = password.contains(where: { ("a"..."z").contains($0) })
        let hasUpper = password.contains(where: { ("A"..."Z").contains($0) })
        let hasDigit = password.contains(where: { ("0"..."9").contains($0) })
        let specialCharacters = Set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
        let hasSpecial = password.contains(where: { specialCharacters.contains($0) })
        let allowedCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
        )
        let hasOnlyAllowed = password.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
        return hasLower && hasUpper && hasDigit && hasSpecial && hasOnlyAllowed
            && (login.isEmpty || !password.localizedCaseInsensitiveContains(login))
    }
}
