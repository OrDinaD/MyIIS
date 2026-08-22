import Foundation

final class LMSActivityContentService {
    static let shared = LMSActivityContentService()

    private let session: URLSession

    private init() {
        session = URLSession(
            configuration: NetworkSecurityPolicy.makeLMSConfiguration()
        )
    }

    func fetchPage(url: URL) async throws -> LMSPageContent {
        let html = try await loadHTML(url: url)
        return try Self.parsePageContent(from: html)
    }

    func fetchFeedback(url: URL) async throws -> LMSFeedbackPage {
        let html = try await loadHTML(url: url)
        return try Self.parseFeedbackPage(from: html, finalURL: url)
    }

    func submitFeedback(page: LMSFeedbackPage, values: [String: String], checkedOptionIDs: Set<String>) async throws -> LMSFeedbackPage {
        guard let form = page.form else { throw LMSActivityContentError.missingForm }

        var fields = form.fields
        for item in form.items {
            switch item.type {
            case .label:
                continue
            case .select, .singleChoice, .text, .textarea:
                guard let name = item.name else { continue }
                fields[name] = values[name] ?? item.defaultValue ?? fields[name] ?? ""
            case .multipleChoice:
                for option in item.options {
                    fields[option.name] = checkedOptionIDs.contains(option.id) ? option.value : "0"
                }
            }
        }
        fields[form.submitName] = form.submitValue

        let response = try await submit(url: form.actionURL, method: form.method, fields: fields)
        return try Self.parseFeedbackPage(from: response.html, finalURL: response.finalURL)
    }

    static func parsePageContent(from html: String) throws -> LMSPageContent {
        let title = html.captureGroup(at: 1, pattern: #"<h1[^>]*>([\s\S]*?)</h1>"#)?
            .strippingSimpleHTML()
            ?? html.captureGroup(at: 1, pattern: #"<title>([\s\S]*?)\|"#)?
            .strippingSimpleHTML()
            ?? "Страница"

        guard var content = htmlInsideDiv(matching: #"<div\b[^>]*role="main"[^>]*>"#, in: html) else {
            throw LMSActivityContentError.missingContent
        }

        if let modifiedRange = content.range(of: #"<div\b[^>]*class="[^"]*\bmodified\b[^"]*""#, options: .regularExpression) {
            content = String(content[..<modifiedRange.lowerBound])
        }

        content = content
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !content.strippingSimpleHTML().isEmpty else {
            throw LMSActivityContentError.missingContent
        }

        return LMSPageContent(title: title, contentHTML: content)
    }

    static func parseFeedbackPage(from html: String, finalURL: URL) throws -> LMSFeedbackPage {
        let title = html.captureGroup(at: 1, pattern: #"<h1[^>]*>([\s\S]*?)</h1>"#)?
            .strippingSimpleHTML()
            ?? html.captureGroup(at: 1, pattern: #"<title>([\s\S]*?)\|"#)?
            .strippingSimpleHTML()
            ?? "Анкета"

        guard let formBlock = html.captureGroup(
            at: 1,
            pattern: #"(<form[^>]*id="feedback_complete_form"[\s\S]*?</form>)"#
        ) else {
            let message = htmlInsideDiv(matching: #"<div\b[^>]*role="main"[^>]*>"#, in: html)?
                .strippingSimpleHTML()
                .trimmedNilIfEmpty
                ?? title
            return LMSFeedbackPage(title: title, form: nil, completionMessage: message)
        }

        guard let action = formBlock.captureGroup(at: 1, pattern: #"action="([^"]+)""#)
            .flatMap(Self.absoluteURL)
            ?? Self.absoluteURL(finalURL.absoluteString) else {
            throw LMSActivityContentError.missingForm
        }

        let method = formBlock.captureGroup(at: 1, pattern: #"method="([^"]+)""#)?.uppercased() ?? "POST"
        let submitName = formBlock.captureGroup(at: 1, pattern: #"<input[^>]*type="submit"[^>]*name="([^"]+)"[^>]*id="id_savevalues""#)
            ?? "savevalues"
        let submitValue = formBlock.captureGroup(at: 1, pattern: #"<input[^>]*id="id_savevalues"[^>]*value="([^"]*)""#)?
            .decodingHTMLEntities()
            ?? "Отправить свои ответы"

        let form = LMSFeedbackForm(
            actionURL: action,
            method: method,
            fields: parseHiddenInputFields(in: formBlock),
            items: parseFeedbackItems(from: formBlock),
            submitName: submitName,
            submitValue: submitValue
        )

        return LMSFeedbackPage(title: title, form: form, completionMessage: nil)
    }
}

private extension LMSActivityContentService {
    struct HTMLResponse {
        let html: String
        let finalURL: URL
    }

    func loadHTML(url: URL) async throws -> String {
        guard NetworkSecurityPolicy.isTrustedLMSURL(url) else {
            throw NetworkSecurityError.untrustedURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let responseURL = http.url,
              NetworkSecurityPolicy.isTrustedLMSURL(responseURL),
              (200 ... 399).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw LMSActivityContentError.invalidResponse
        }
        return html
    }

    func submit(url: URL, method: String, fields: [String: String]) async throws -> HTMLResponse {
        guard NetworkSecurityPolicy.isTrustedLMSURL(url) else {
            throw NetworkSecurityError.untrustedURL
        }
        var requestURL = url
        var request = URLRequest(url: url)
        let normalizedMethod = method.uppercased()

        if normalizedMethod == "GET" {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                queryItems.append(contentsOf: fields.map { URLQueryItem(name: $0.key, value: $0.value) })
                components.queryItems = queryItems
                requestURL = components.url ?? url
                request = URLRequest(url: requestURL)
            }
            request.httpMethod = "GET"
        } else {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.percentEncoded(fields)
        }

        guard NetworkSecurityPolicy.isTrustedLMSURL(requestURL) else {
            throw NetworkSecurityError.untrustedURL
        }
        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let responseURL = http.url,
              NetworkSecurityPolicy.isTrustedLMSURL(responseURL),
              (200 ... 399).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw LMSActivityContentError.invalidResponse
        }

        return HTMLResponse(html: html, finalURL: response.url ?? requestURL)
    }
}

private extension LMSActivityContentService {
    static func parseHiddenInputFields(in html: String) -> [String: String] {
        var fields: [String: String] = [:]
        for input in html.matches(pattern: #"<input[^>]*>"#) {
            let source = input.fullText
            guard source.captureGroup(at: 1, pattern: #"type="([^"]+)""#)?.lowercased() == "hidden",
                  let name = source.captureGroup(at: 1, pattern: #"name="([^"]+)""#) else {
                continue
            }
            let value = source.captureGroup(at: 1, pattern: #"value="([^"]*)""#) ?? ""
            fields[name.decodingHTMLEntities()] = value.decodingHTMLEntities()
        }
        return fields
    }

    static func parseFeedbackItems(from formBlock: String) -> [LMSFeedbackItem] {
        feedbackItemBlocks(in: formBlock).compactMap(parseFeedbackItem)
    }

    static func parseFeedbackItem(_ block: String) -> LMSFeedbackItem? {
        guard let id = block.captureGroup(at: 1, pattern: #"<div\s+id="(?:fitem_id_|fgroup_id_group_)([^"]+)""#) else {
            return nil
        }

        let isRequired = block.contains("Обязательное поле")
        if isLabelItem(block, id: id) {
            return parseLabelItem(block, id: id)
        }
        if block.contains("<select") {
            return parseSelectItem(block, id: id, isRequired: isRequired)
        }
        if block.contains("feedback-item-textarea") || block.contains("<textarea") {
            return parseTextAreaItem(block, id: id, isRequired: isRequired)
        }
        if block.contains("feedback-item-textfield") || block.contains(#"data-fieldtype="text""#) {
            return parseTextFieldItem(block, id: id, isRequired: isRequired)
        }
        return parseChoiceItem(block, id: id, isRequired: isRequired)
    }

    static func isLabelItem(_ block: String, id: String) -> Bool {
        block.contains("feedback-item-label") || block.contains(#"data-fieldtype="static""#) && id.hasPrefix("label_")
    }

    static func parseLabelItem(_ block: String, id: String) -> LMSFeedbackItem {
        let html = block.captureGroup(
            at: 1,
            pattern: #"<div[^>]*class="[^"]*form-control-static[^"]*"[^>]*>([\s\S]*?)</div>\s*<div class="form-control-feedback"#
        ) ?? block
        return LMSFeedbackItem(
            id: id,
            promptHTML: cleanedPromptHTML(html),
            type: .label,
            name: nil,
            options: [],
            defaultValue: nil,
            isRequired: false
        )
    }

    static func parseSelectItem(_ block: String, id: String, isRequired: Bool) -> LMSFeedbackItem? {
        guard let name = block.captureGroup(at: 1, pattern: #"<select[^>]*name="([^"]+)""#) else { return nil }
        let options = block.matches(pattern: #"<option[^>]*value="([^"]*)"([^>]*)>([\s\S]*?)</option>"#).compactMap { match -> LMSFeedbackOption? in
            guard let value = match.groups[safe: 0] else { return nil }
            let attributes = match.groups[safe: 1] ?? ""
            let label = cleanedPromptHTML(match.groups[safe: 2] ?? "")
            let title = label.strippingSimpleHTML().trimmedNilIfEmpty ?? "Не выбрано"
            return LMSFeedbackOption(
                id: "\(name)-\(value)",
                name: name,
                value: value.decodingHTMLEntities(),
                labelHTML: title,
                isSelected: attributes.contains("selected")
            )
        }
        return LMSFeedbackItem(
            id: id,
            promptHTML: cleanedPromptHTML(labelHTML(in: block)),
            type: .select,
            name: name.decodingHTMLEntities(),
            options: options,
            defaultValue: options.first(where: { $0.isSelected })?.value,
            isRequired: isRequired
        )
    }

    static func parseTextAreaItem(_ block: String, id: String, isRequired: Bool) -> LMSFeedbackItem? {
        guard let name = block.captureGroup(at: 1, pattern: #"<textarea[^>]*name="([^"]+)""#) else { return nil }
        let defaultValue = block.captureGroup(at: 1, pattern: #"<textarea[^>]*>([\s\S]*?)</textarea>"#)?.decodingHTMLEntities()
        return LMSFeedbackItem(
            id: id,
            promptHTML: cleanedPromptHTML(labelHTML(in: block)),
            type: .textarea,
            name: name.decodingHTMLEntities(),
            options: [],
            defaultValue: defaultValue,
            isRequired: isRequired
        )
    }

    static func parseTextFieldItem(_ block: String, id: String, isRequired: Bool) -> LMSFeedbackItem? {
        guard let name = block.captureGroup(at: 1, pattern: #"<input[^>]*type="text"[^>]*name="([^"]+)""#) else { return nil }
        let defaultValue = block.captureGroup(at: 1, pattern: #"<input[^>]*type="text"[^>]*value="([^"]*)""#)?.decodingHTMLEntities()
        return LMSFeedbackItem(
            id: id,
            promptHTML: cleanedPromptHTML(labelHTML(in: block)),
            type: .text,
            name: name.decodingHTMLEntities(),
            options: [],
            defaultValue: defaultValue,
            isRequired: isRequired
        )
    }

    static func parseChoiceItem(_ block: String, id: String, isRequired: Bool) -> LMSFeedbackItem? {
        let options = feedbackOptions(in: block)
        guard !options.isEmpty else { return nil }
        let isMultiple = options.contains { option in
            block.contains(#"type="checkbox""#) || option.name.contains("[")
        }
        return LMSFeedbackItem(
            id: id,
            promptHTML: cleanedPromptHTML(groupPromptHTML(in: block)),
            type: isMultiple ? .multipleChoice : .singleChoice,
            name: isMultiple ? nil : options.first?.name,
            options: options,
            defaultValue: options.first(where: { $0.isSelected })?.value,
            isRequired: isRequired
        )
    }

    static func feedbackItemBlocks(in formBlock: String) -> [String] {
        let pattern = #"<div\s+id="(?:fitem_id_(?!requiredfields)[^"]+|fgroup_id_group_(?!buttonar)[^"]+)"[^>]*>"#
        let starts = formBlock.matches(pattern: pattern)
        guard !starts.isEmpty else { return [] }

        return starts.enumerated().map { index, match in
            let start = match.fullRange.lowerBound
            let end = index + 1 < starts.count ? starts[index + 1].fullRange.lowerBound : formBlock.endIndex
            return String(formBlock[start ..< end])
        }.filter { block in
            !block.contains(#"id="fgroup_id_buttonar""#) && !block.contains(#"id="fitem_id_requiredfields""#)
        }
    }

    static func feedbackOptions(in block: String) -> [LMSFeedbackOption] {
        block.matches(pattern: #"<label[^>]*>([\s\S]*?)</label>"#).compactMap { labelMatch -> LMSFeedbackOption? in
            let labelBlock = labelMatch.groups[safe: 0] ?? ""
            guard let input = labelBlock.matches(pattern: #"<input[^>]*type="(?:radio|checkbox)"[^>]*>"#).first?.fullText,
                  let name = input.captureGroup(at: 1, pattern: #"name="([^"]+)""#),
                  let value = input.captureGroup(at: 1, pattern: #"value="([^"]*)""#) else {
                return nil
            }
            let id = input.captureGroup(at: 1, pattern: #"id="([^"]+)""#) ?? "\(name)-\(value)"
            let optionHTML = labelBlock
                .replacingOccurrences(of: #"<input[^>]*>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"<span[^>]*>[\s\S]*?</span>"#, with: "", options: .regularExpression)

            return LMSFeedbackOption(
                id: id.decodingHTMLEntities(),
                name: name.decodingHTMLEntities(),
                value: value.decodingHTMLEntities(),
                labelHTML: cleanedPromptHTML(optionHTML),
                isSelected: input.contains("checked")
            )
        }
    }

    static func labelHTML(in block: String) -> String {
        block.captureGroup(at: 1, pattern: #"<label[^>]*>([\s\S]*?)</label>"#) ?? ""
    }

    static func groupPromptHTML(in block: String) -> String {
        block.captureGroup(at: 1, pattern: #"<p[^>]*id="fgroup_id_[^"]+_label"[^>]*>([\s\S]*?)</p>"#)
            ?? block.captureGroup(at: 1, pattern: #"<legend[^>]*>([\s\S]*?)</legend>"#)
            ?? ""
    }

    static func cleanedPromptHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"<i[^>]*aria-label="Обязательное поле"[^>]*></i>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<input[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func htmlInsideDiv(matching startPattern: String, in html: String) -> String? {
        guard let startRange = html.range(of: startPattern, options: .regularExpression) else { return nil }
        let tail = String(html[startRange.upperBound...])
        let tags = tail.matches(pattern: #"</?div\b[^>]*>"#)
        var depth = 1

        for tag in tags {
            if tag.fullText.lowercased().hasPrefix("</div") {
                depth -= 1
            } else {
                depth += 1
            }

            if depth == 0 {
                return String(tail[..<tag.fullRange.lowerBound])
            }
        }

        return nil
    }

    static func absoluteURL(_ raw: String) -> URL? {
        NetworkSecurityPolicy.trustedLMSURL(raw)
    }

    static func percentEncoded(_ fields: [String: String]) -> Data? {
        let bodyString = fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(bodyString.utf8)
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
