import CoreGraphics
import SwiftUI

enum TeacherInitials {
    nonisolated static func make(
        firstName: String?, middleName: String?, lastName: String?, languageCode: String
    ) -> String {
        let names = [firstName, middleName].compactMap { value -> String? in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }
        let selected = names.isEmpty ? [lastName ?? ""] : names
        let initials = selected.compactMap { name -> String? in
            guard let first = name.first else { return nil }
            guard languageCode.hasPrefix("en") else { return String(first).uppercased() }
            let latin = String(first).applyingTransform(.toLatin, reverse: false) ?? String(first)
            return latin.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
                .first.map { String($0).uppercased() }
        }.joined()
        return initials.isEmpty ? "?" : initials
    }
}

enum TeacherPhotoValidation {
    nonisolated static func isBlank(_ image: CGImage?) -> Bool {
        guard let image else { return true }
        var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 8, height: 8, bitsPerComponent: 8,
                bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 8, height: 8))
            return true
        }
        guard drawn else { return false }
        return stride(from: 0, to: pixels.count, by: 4).allSatisfy { index in
            pixels[index + 3] == 0 ||
                (pixels[index] >= 253 && pixels[index + 1] >= 253 && pixels[index + 2] >= 253)
        }
    }
}

struct TeacherAvatarView: View {
    private let photoURL: URL?
    private let initials: String
    let size: CGFloat
    private let photoAccessibilityLabel: String
    private let onPhotoTap: (() -> Void)?

    init(teacher: DisciplineEmployee, size: CGFloat, onPhotoTap: (() -> Void)? = nil) {
        self.init(
            photoLink: teacher.photoLink, employeeID: teacher.id,
            firstName: teacher.firstName, middleName: teacher.middleName,
            lastName: teacher.lastName, size: size, onPhotoTap: onPhotoTap
        )
    }

    init(
        photoLink: String?, employeeID: Int, firstName: String?,
        middleName: String?, lastName: String?, size: CGFloat, onPhotoTap: (() -> Void)? = nil
    ) {
        photoURL = ScheduleEmployeePhotoURL.make(photoLink: photoLink, employeeID: employeeID)
        initials = TeacherInitials.make(
            firstName: firstName, middleName: middleName, lastName: lastName,
            languageCode: Bundle.main.preferredLocalizations.first ?? "ru"
        )
        let fullName = [lastName, firstName, middleName].compactMap { $0 }.joined(separator: " ")
        photoAccessibilityLabel = String(format: String(localized: "Открыть фотографию %@"), fullName)
        self.onPhotoTap = onPhotoTap
        self.size = size
    }

    var body: some View {
        CachedAsyncImage(url: photoURL, maxPixelSize: 360, rejectBlankImages: true) { image in
            if let onPhotoTap {
                Button(action: onPhotoTap) {
                    photo(image)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(photoAccessibilityLabel)
            } else {
                photo(image)
                    .accessibilityHidden(true)
            }
        } placeholder: {
            avatarPlaceholder
        }
        .frame(width: size, height: size)
    }

    private func photo(_ image: Image) -> some View {
        image.resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Color.accentColor.opacity(0.12))
            Text(initials)
                .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
