import Foundation

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

extension String {
    struct RegexMatch {
        let fullText: String
        let fullRange: Range<String.Index>
        let groups: [String]
    }

    func matches(pattern: String) -> [RegexMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return [] }
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        return regex.matches(in: self, range: nsRange).compactMap { match in
            guard let fullRange = Range(match.range(at: 0), in: self) else { return nil }
            var groups: [String] = []
            if match.numberOfRanges > 1 {
                for idx in 1..<match.numberOfRanges {
                    let groupRange = match.range(at: idx)
                    if groupRange.location != NSNotFound, let captureRange = Range(groupRange, in: self) {
                        groups.append(String(self[captureRange]))
                    } else {
                        groups.append("")
                    }
                }
            }
            return RegexMatch(
                fullText: String(self[fullRange]),
                fullRange: fullRange,
                groups: groups
            )
        }
    }

    func captureGroup(at index: Int, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return nil }
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        if let match = regex.firstMatch(in: self, range: nsRange) {
            if match.numberOfRanges > index {
                let range = match.range(at: index)
                if let captureRange = Range(range, in: self) {
                    return String(self[captureRange])
                }
            }
        }
        return nil
    }

    func captureGroups(at index: Int, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return [] }
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        let matches = regex.matches(in: self, range: nsRange)
        return matches.compactMap { match in
            if match.numberOfRanges > index {
                let range = match.range(at: index)
                if let captureRange = Range(range, in: self) {
                    return String(self[captureRange])
                }
            }
            return nil
        }
    }

    func decodingHTMLEntities() -> String {
        var decoded = self
        let replacements: [(String, String)] = [
            ("&quot;", "\""),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&apos;", "'"),
            ("&#039;", "'"),
            ("&nbsp;", " ")
        ]

        for (entity, value) in replacements where decoded.contains(entity) {
            decoded = decoded.replacingOccurrences(of: entity, with: value)
        }

        return decoded
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension LMSService {
    static func parseSections(from html: String) -> [LMSSection] {
        var sections: [LMSSection] = []
        let sectionPattern = #"<li[^>]*data-for="section"[^>]*data-sectionname="([^"]+)"[^>]*>"#
        let sectionMatches = html.matches(pattern: sectionPattern)

        for (idx, sectionMatch) in sectionMatches.enumerated() {
            guard let sectionNameRaw = sectionMatch.groups[safe: 0] else { continue }
            let sectionName = sectionNameRaw.decodingHTMLEntities()

            let blockStart = sectionMatch.fullRange.lowerBound
            let blockEnd = idx + 1 < sectionMatches.count ? sectionMatches[idx + 1].fullRange.lowerBound : html.endIndex
            let sectionBlock = String(html[blockStart..<blockEnd])

            let modules = parseModules(from: sectionBlock, sectionIndex: idx)
            if !modules.isEmpty {
                sections.append(LMSSection(name: sectionName, modules: modules))
            }
        }

        if sections.isEmpty {
            let fallbackModules = parseModules(from: html, sectionIndex: 0)
            if !fallbackModules.isEmpty {
                sections.append(LMSSection(name: "Материалы курса", modules: fallbackModules))
            }
        }

        return sections
    }

    // swiftlint:disable:next function_body_length
    private static func parseModules(from source: String, sectionIndex: Int) -> [LMSModule] {
        let activityPattern =
            #"<li[^>]*class="[^"]*activity[^"]*activity-wrapper[^"]*"[^>]*id="module-(\d+)"[^>]*>([\s\S]*?)"#
            + #"(?=<li[^>]*class="[^"]*activity[^"]*activity-wrapper[^"]*"|<\/ul>|$)"#
        let matches = source.matches(pattern: activityPattern)
        var modules: [LMSModule] = []
        var fallbackIndex = 0

        for match in matches {
            let moduleId = Int(match.groups[safe: 0] ?? "") ?? ((sectionIndex + 1) * 10_000 + fallbackIndex + 1)
            fallbackIndex += 1
            let moduleFull = match.fullText

            let modName = moduleFull.captureGroup(at: 1, pattern: #"data-activityname="([^"]+)""#)?
                .decodingHTMLEntities()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Элемент \(moduleId)"

            let modTypeStr = moduleFull.captureGroup(at: 1, pattern: #"modtype_([^"\s]+)"#) ?? "unknown"
            let type = LMSModule.LMSModuleType(rawValue: modTypeStr) ?? .unknown

            let modHref =
                moduleFull.captureGroup(at: 1, pattern: #"<a[^>]*class="[^"]*aalink[^"]*"[^>]*href="([^"]+)""#)
                ?? moduleFull.captureGroup(at: 1, pattern: #"href="([^"]+)""#)
            let modUrl = modHref
                .map { $0.decodingHTMLEntities() }
                .flatMap { URL(string: $0, relativeTo: URL(string: "https://lms.bsuir.by"))?.absoluteURL }

            let descriptionRaw = moduleFull.captureGroup(
                at: 1,
                pattern: #"<div[^>]*class="[^"]*contentafterlink[^"]*"[^>]*>([\s\S]*?)<\/div>"#
            )
            let description = descriptionRaw?
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
                .decodingHTMLEntities()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let indentText = moduleFull.captureGroup(at: 1, pattern: #"mod-indent-(\d+)"#)
            let indent = Int(indentText ?? "0") ?? 0

            modules.append(
                LMSModule(
                    id: moduleId,
                    name: modName,
                    description: description?.isEmpty == true ? nil : description,
                    type: type,
                    url: modUrl,
                    indent: indent
                )
            )
        }

        if modules.isEmpty {
            let cardPattern = #"<div[^>]*class="[^"]*activity-item[^"]*"[^>]*data-activityname="([^"]+)"[^>]*>"#
            let cardMatches = source.matches(pattern: cardPattern)

            for (cardIndex, cardMatch) in cardMatches.enumerated() {
                let moduleId = (sectionIndex + 1) * 10_000 + cardIndex + 1
                let start = cardMatch.fullRange.lowerBound
                let end = cardIndex + 1 < cardMatches.count ? cardMatches[cardIndex + 1].fullRange.lowerBound : source.endIndex
                let moduleBlock = String(source[start..<end])

                let modName = cardMatch.groups[safe: 0]?
                    .decodingHTMLEntities()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "Элемент \(moduleId)"

                let modTypeStr = moduleBlock.captureGroup(at: 1, pattern: #"modtype_([^"\s]+)"#) ?? "unknown"
                let type = LMSModule.LMSModuleType(rawValue: modTypeStr) ?? .unknown

                let modHref =
                    moduleBlock.captureGroup(at: 1, pattern: #"<a[^>]*class="[^"]*aalink[^"]*"[^>]*href="([^"]+)""#)
                    ?? moduleBlock.captureGroup(at: 1, pattern: #"href="([^"]+)""#)
                let modUrl = modHref
                    .map { $0.decodingHTMLEntities() }
                    .flatMap { URL(string: $0, relativeTo: URL(string: "https://lms.bsuir.by"))?.absoluteURL }

                modules.append(
                    LMSModule(
                        id: moduleId,
                        name: modName,
                        description: nil,
                        type: type,
                        url: modUrl,
                        indent: 0
                    )
                )
            }
        }

        return modules
    }
}
