import XCTest

final class BelarusianLocalizationTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testMainBelarusianLocalizationCoversRussianKeys() throws {
        let russian = try stringsDictionary(language: "ru")
        let belarusian = try stringsDictionary(language: "be")
        let missingKeys = Set(russian.keys).subtracting(belarusian.keys)

        XCTAssertTrue(
            missingKeys.isEmpty,
            "Белорусская локализация не содержит ключи: \(missingKeys.sorted().joined(separator: ", "))"
        )

        for key in russian.keys {
            let sourcePlaceholders = placeholders(in: try XCTUnwrap(russian[key]))
            let translatedPlaceholders = placeholders(in: try XCTUnwrap(belarusian[key]))
            XCTAssertEqual(
                sourcePlaceholders,
                translatedPlaceholders,
                "Не совпадают плейсхолдеры для ключа \(key)"
            )
        }
    }

    func testCriticalBelarusianTranslations() throws {
        let belarusian = try stringsDictionary(language: "be")
        let expected = [
            "about_app_language_title": "Мова праграмы",
            "library_my_books_subtitle": "Даныя з ІІС для раздзела бібліятэкі.",
            "Не удалось обновить данные": "Не ўдалося абнавіць даныя",
            "Техническая поддержка": "Тэхнічная падтрымка",
            "Дипломный проект": "Дыпломны праект",
            "Портал БГУИР": "Партал БДУІР",
            "services_schedule_group_format": "Група %@"
        ]

        for (key, value) in expected {
            XCTAssertEqual(belarusian[key], value, "Некорректный перевод для ключа \(key)")
        }
    }

    func testServicesScheduleGroupFormatInAllLanguages() throws {
        let expectedFormats = [
            "ru": "Группа %@",
            "en": "Group %@",
            "be": "Група %@",
            "uk": "Група %@"
        ]
        for (lang, expectedFormat) in expectedFormats {
            let dict = try stringsDictionary(language: lang)
            let format = try XCTUnwrap(dict["services_schedule_group_format"], "Ключ services_schedule_group_format отсутствует в \(lang)")
            XCTAssertEqual(format, expectedFormat, "Неверный формат для языка \(lang)")
            let formatted = String(format: format, "124401")
            XCTAssertFalse(formatted.contains("%@"))
            XCTAssertTrue(formatted.contains("124401"))
        }
    }

    func testExtensionCatalogsContainBelarusianLocalizations() throws {
        let catalogPaths = [
            "MyIISWidget/Localizable.xcstrings",
            "MyIISMessages/Localizable.xcstrings",
            "MyIIS/InfoPlist.xcstrings",
            "MyIIS/AppShortcuts.xcstrings"
        ]

        for relativePath in catalogPaths {
            let url = repositoryRoot.appending(path: relativePath)
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw XCTSkip("Файл \(relativePath) недоступен из тестового окружения")
            }
            let data = try Data(contentsOf: url)
            let catalog = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any],
                "Не удалось прочитать \(relativePath)"
            )
            let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

            for (key, rawEntry) in strings {
                let entry = try XCTUnwrap(rawEntry as? [String: Any])
                guard let localizations = entry["localizations"] as? [String: Any] else {
                    // Пустая запись хранит исходную русскую строку и не является переводом.
                    continue
                }
                let belarusian = try XCTUnwrap(
                    localizations["be"] as? [String: Any],
                    "В \(relativePath) нет белорусского перевода для \(key)"
                )
                let stringUnit = try XCTUnwrap(belarusian["stringUnit"] as? [String: Any])
                let value = try XCTUnwrap(stringUnit["value"] as? String)
                XCTAssertFalse(value.isEmpty, "Пустой белорусский перевод для \(key) в \(relativePath)")
            }
        }
    }

    func testAppShortcutVariablesArePreserved() throws {
        let url = repositoryRoot.appending(path: "MyIIS/AppShortcuts.xcstrings")
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw XCTSkip("Файл AppShortcuts.xcstrings недоступен из тестового окружения")
        }
        let data = try Data(contentsOf: url)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        for (key, rawEntry) in strings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any])
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let belarusian = try XCTUnwrap(localizations["be"] as? [String: Any])
            let stringUnit = try XCTUnwrap(belarusian["stringUnit"] as? [String: Any])
            let value = try XCTUnwrap(stringUnit["value"] as? String)

            XCTAssertEqual(
                shortcutVariables(in: key),
                shortcutVariables(in: value),
                "В App Shortcut потеряна переменная для \(key)"
            )
        }
    }

    private func stringsDictionary(language: String) throws -> [String: String] {
        let localizationURL = try XCTUnwrap(
            Bundle.main.url(forResource: language, withExtension: "lproj"),
            "В приложении нет \(language).lproj"
        )
        let stringsURL = localizationURL.appending(path: "Localizable.strings")
        return try XCTUnwrap(
            NSDictionary(contentsOf: stringsURL) as? [String: String],
            "Не удалось прочитать \(stringsURL.path)"
        )
    }

    private func placeholders(in value: String) -> [String] {
        matches(pattern: "%(?:\\d+\\$)?(?:@|lld|ld|d|f)", in: value)
    }

    private func shortcutVariables(in value: String) -> [String] {
        matches(pattern: "\\$\\{[^}]+\\}", in: value)
    }

    private func matches(pattern: String, in value: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }.sorted()
    }
}
