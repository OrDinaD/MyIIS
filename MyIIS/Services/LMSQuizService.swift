import Foundation

final class LMSQuizService {
    static let shared = LMSQuizService()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: configuration)
    }

    func fetchOverview(quizURL: URL) async throws -> LMSQuizOverview {
        let html = try await loadHTML(url: quizURL)

        let title = html.captureGroup(at: 1, pattern: #"<h2>(.*?)</h2>"#)?.trimmingCharacters(in: .whitespacesAndNewlines).decodingHTMLEntities()
            ?? html.captureGroup(at: 1, pattern: #"<title>(.*?)\|"#)?.trimmingCharacters(in: .whitespacesAndNewlines).decodingHTMLEntities()
            ?? "Тест"
        let courseTitle = html.captureGroup(at: 1, pattern: #"<h1>(.*?)</h1>"#)?
            .strippingHTML()
            .trimmedNilIfEmpty

        let quizId = URLComponents(url: quizURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "id" })?
            .value
            .flatMap(Int.init)

        let resumeAttemptURL = html
            .captureGroup(at: 1, pattern: #"href=\"(https://lms\.bsuir\.by/mod/quiz/attempt\.php[^\"]*)\""#)
            .flatMap(self.absoluteURL)

        let startForm = parseStartForm(from: html)

        let warningText = html.captureGroup(
            at: 1,
            pattern: #"<div class=\"quizinfo\">[\s\S]*?<div class=\"quizattempt\">([\s\S]*?)</div>"#
        )?
        .strippingHTML()
        .trimmedNilIfEmpty

        let previousAttempts = parsePreviousAttempts(from: html)

        return LMSQuizOverview(
            title: title,
            courseTitle: courseTitle,
            quizURL: quizURL,
            quizId: quizId,
            resumeAttemptURL: resumeAttemptURL,
            startForm: startForm,
            preflightForm: nil,
            warningText: warningText,
            previousAttempts: previousAttempts
        )
    }

    func startAttempt(using overview: LMSQuizOverview) async throws -> LMSQuizScreenState {
        if let resumeURL = overview.resumeAttemptURL {
            return try await fetchScreen(url: resumeURL)
        }

        // If the preflight form is already on the overview page, we submit it directly
        if let preflightForm = overview.preflightForm {
            let response = try await submit(form: preflightForm)
            return try parseScreen(from: response)
        }

        guard let form = overview.startForm else {
            throw LMSQuizError.missingStartForm
        }

        let response = try await submit(form: form)

        if let preflightForm = parsePreflightForm(from: response.html) {
            let preflightResponse = try await submit(form: preflightForm)
            return try parseScreen(from: preflightResponse)
        }

        return try parseScreen(from: response)
    }

    func submitAttempt(page: LMSQuizAttemptPage, answers: [String: String], action: AttemptSubmitAction) async throws -> LMSQuizScreenState {
        var fields: [String: String] = [
            "attempt": String(page.attemptId),
            "thispage": String(page.thisPage),
            "nextpage": action.nextPageValue(current: page),
            "timeup": page.timeup,
            "sesskey": page.sesskey,
            "mdlscrollto": page.mdlscrollto,
            "slots": page.slots,
            "next": action.buttonLabel
        ]

        for question in page.questions {
            fields[question.flaggedFieldName] = question.flaggedValue
            fields[question.sequenceFieldName] = question.sequenceValue
            fields[question.answerFieldName] = answers[question.id] ?? question.selectedAnswer ?? "-1"
        }

        let form = LMSQuizForm(actionURL: page.actionURL, method: "POST", fields: fields)
        let response = try await submitMultipart(form: form)
        return try parseScreen(from: response)
    }

    func finishQuiz(summary: LMSQuizSummaryPage) async throws -> LMSQuizScreenState {
        guard let finishForm = summary.finishForm else {
            throw LMSQuizError.missingFinishForm
        }

        let response = try await submit(form: finishForm)
        return try parseScreen(from: response)
    }

    func returnToAttempt(from summary: LMSQuizSummaryPage) async throws -> LMSQuizScreenState {
        guard let returnForm = summary.returnForm else {
            throw LMSQuizError.missingAttemptData
        }

        let response = try await submit(form: returnForm)
        return try parseScreen(from: response)
    }

}

private extension LMSQuizService {
    private func fetchScreen(url: URL) async throws -> LMSQuizScreenState {
        let html = try await loadHTML(url: url)
        return try parseScreen(from: HTMLResponse(html: html, finalURL: url))
    }

    private func parseScreen(from response: HTMLResponse) throws -> LMSQuizScreenState {
        let html = response.html

        if html.contains("id=\"page-mod-quiz-attempt\"") {
            return .attempt(try parseAttemptPage(html: html, finalURL: response.finalURL))
        }

        if html.contains("id=\"page-mod-quiz-summary\"") {
            return .summary(try parseSummaryPage(html: html, finalURL: response.finalURL))
        }

        if html.contains("quiz-reviewsummary") || html.contains("Отправлено") || html.contains("Ваш ответ") {
            let completion = html.captureGroup(at: 1, pattern: #"<h2>(.*?)</h2>"#)?.strippingHTML().trimmedNilIfEmpty
                ?? "Тест отправлен"
            return .completion(completion)
        }

        if response.finalURL.path.contains("/mod/quiz/view.php") {
            return .overview(try parseOverviewFromLoadedHTML(html: html, url: response.finalURL))
        }

        throw LMSQuizError.parseFailed
    }

    private func parseOverviewFromLoadedHTML(html: String, url: URL) throws -> LMSQuizOverview {
        let title = html.captureGroup(at: 1, pattern: #"<h2>(.*?)</h2>"#)?.strippingHTML().trimmedNilIfEmpty ?? "Тест"
        let courseTitle = html.captureGroup(at: 1, pattern: #"<h1>(.*?)</h1>"#)?
            .strippingHTML()
            .trimmedNilIfEmpty
        let resumeAttemptURL = html
            .captureGroup(at: 1, pattern: #"href=\"(https://lms\.bsuir\.by/mod/quiz/attempt\.php[^\"]*)\""#)
            .flatMap(self.absoluteURL)
        let startForm = parseStartForm(from: html)
        let preflightForm = parsePreflightForm(from: html)
        let warningText = html.captureGroup(
            at: 1,
            pattern: #"<div class=\"quizinfo\">[\s\S]*?<div class=\"quizattempt\">([\s\S]*?)</div>"#
        )?
        .strippingHTML()
        .trimmedNilIfEmpty
        let previousAttempts = parsePreviousAttempts(from: html)

        return LMSQuizOverview(
            title: title,
            courseTitle: courseTitle,
            quizURL: url,
            quizId: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value.flatMap(Int.init),
            resumeAttemptURL: resumeAttemptURL,
            startForm: startForm,
            preflightForm: preflightForm,
            warningText: warningText,
            previousAttempts: previousAttempts
        )
    }

    private func parseStartForm(from html: String) -> LMSQuizForm? {
        guard let formBlock = html.captureGroup(
            at: 1,
            pattern: #"(<form[^>]*action=\"https://lms\.bsuir\.by/mod/quiz/startattempt\.php[^\"]*\"[\s\S]*?</form>)"#
        ) else {
            return nil
        }

        let action = formBlock.captureGroup(at: 1, pattern: #"action=\"([^\"]+)\""#).flatMap(self.absoluteURL)
        let method = formBlock.captureGroup(at: 1, pattern: #"method=\"([^\"]+)\""#)?.uppercased() ?? "GET"
        let fields = parseInputFields(in: formBlock)

        guard let action else { return nil }
        return LMSQuizForm(actionURL: action, method: method, fields: fields)
    }

    private func parsePreflightForm(from html: String) -> LMSQuizForm? {
        guard let formBlock = html.captureGroup(
            at: 1,
            pattern: #"(<form[^>]*id=\"mod_quiz_preflight_form\"[\s\S]*?</form>)"#
        ) else {
            return nil
        }

        let action = formBlock.captureGroup(at: 1, pattern: #"action=\"([^\"]+)\""#).flatMap(self.absoluteURL)
        let method = formBlock.captureGroup(at: 1, pattern: #"method=\"([^\"]+)\""#)?.uppercased() ?? "POST"
        var fields = parseInputFields(in: formBlock)
        fields.removeValue(forKey: "cancel")

        if let submitValue = formBlock.captureGroup(at: 1, pattern: #"name=\"submitbutton\"[^>]*value=\"([^\"]+)\""#) {
            fields["submitbutton"] = submitValue.decodingHTMLEntities()
        } else {
            fields["submitbutton"] = "Начать попытку"
        }

        guard let action else { return nil }
        return LMSQuizForm(actionURL: action, method: method, fields: fields)
    }

    // swiftlint:disable:next function_body_length
    private func parseAttemptPage(html: String, finalURL: URL) throws -> LMSQuizAttemptPage {
        guard let formBlock = html.captureGroup(at: 1, pattern: #"(<form[^>]*id=\"responseform\"[\s\S]*?</form>)"#) else {
            throw LMSQuizError.missingAttemptData
        }

        guard let actionURL = formBlock.captureGroup(at: 1, pattern: #"action=\"([^\"]+)\""#).flatMap(self.absoluteURL) else {
            throw LMSQuizError.missingAttemptData
        }

        let fields = parseInputFields(in: formBlock)

        guard let attemptId = fields["attempt"].flatMap(Int.init),
              let sesskey = fields["sesskey"],
              let thisPage = fields["thispage"].flatMap(Int.init),
              let nextPage = fields["nextpage"].flatMap(Int.init) else {
            throw LMSQuizError.missingAttemptData
        }

        let title = html.captureGroup(at: 1, pattern: #"<h1>(.*?)</h1>"#)?.strippingHTML().trimmedNilIfEmpty ?? "Тест"
        let pageTitle = html.captureGroup(at: 1, pattern: #"<title>(.*?)\|"#)?.strippingHTML().trimmedNilIfEmpty
        let timerRemainingSeconds = html.captureGroup(
            at: 1,
            pattern: #"M\.mod_quiz\.timer\.init\(Y,\s*(\d+)\s*,\s*(?:true|false)\s*\)"#
        ).flatMap { value in
            Int(value)
        }

        let questionMatches = formBlock.matches(pattern: #"<div id=\"question-[^\"]+\" class=\"que [^\"]+\">[\s\S]*?</div></div></div>"#)

        let questions = questionMatches.compactMap { match in
            parseQuestionBlock(match.fullText)
        }

        let navMatches = html.matches(pattern: #"<a class=\"qnbutton ([^\"]*)\" id=\"quiznavbutton(\d+)\"[^>]*title=\"([^\"]+)\"[^>]*href=\"([^\"]*)\""#)
        let navigation = navMatches.compactMap { match -> LMSQuizNavigationItem? in
            guard let idText = match.groups[safe: 1],
                  let id = Int(idText),
                  let title = match.groups[safe: 2],
                  let href = match.groups[safe: 3] else {
                return nil
            }
            let isCurrent = (match.groups[safe: 0] ?? "").contains("thispage")
            let state = title.components(separatedBy: "-").dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
            let url = href == "#" ? nil : self.absoluteURL(href)
            return LMSQuizNavigationItem(
                id: id,
                pageIndex: id - 1,
                label: "\(id)",
                state: state,
                isCurrent: isCurrent,
                url: url
            )
        }

        let endAttemptURL = html.captureGroup(at: 1, pattern: #"<a class=\"endtestlink[^\"]*\" href=\"([^\"]+)\""#)
            .flatMap(self.absoluteURL)

        let cmid = URLComponents(url: actionURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "cmid" })?
            .value
            .flatMap(Int.init)

        return LMSQuizAttemptPage(
            title: title,
            pageTitle: pageTitle,
            actionURL: actionURL,
            cmid: cmid,
            attemptId: attemptId,
            sesskey: sesskey,
            thisPage: thisPage,
            nextPage: nextPage,
            timeup: fields["timeup"] ?? "0",
            mdlscrollto: fields["mdlscrollto"] ?? "",
            slots: fields["slots"] ?? "",
            questions: questions,
            navigation: navigation,
            endAttemptURL: endAttemptURL,
            timerRemainingSeconds: timerRemainingSeconds
        )
    }

    private func parseQuestionBlock(_ block: String) -> LMSQuizQuestion? {
        guard let questionContainerId = block.captureGroup(at: 1, pattern: #"id=\"question-([^\"]+)\""#),
              let qno = block.captureGroup(at: 1, pattern: #"<span class=\"qno\">(.*?)</span>"#)?.strippingHTML().trimmedNilIfEmpty,
              let sequenceFieldName = block.captureGroup(at: 1, pattern: #"name=\"([^\"]*_:sequencecheck)\""#),
              let sequenceValue = block.captureGroup(at: 1, pattern: #"name=\"[^\"]*_:sequencecheck\" value=\"([^\"]*)\""#),
              let flaggedFieldName = block.captureGroup(at: 1, pattern: #"name=\"([^\"]*_:flagged)\""#),
              let flaggedValue = block.captureGroup(at: 1, pattern: #"name=\"[^\"]*_:flagged\" value=\"([^\"]*)\""#),
              let answerFieldName = block.captureGroup(at: 1, pattern: #"name=\"([^\"]*_answer)\""#)
        else {
            return nil
        }

        let textHTML = block.captureGroup(at: 1, pattern: #"<div class=\"qtext\">([\s\S]*?)</div>"#) ?? ""
        let textImages = extractImageURLs(fromHTML: textHTML)
        let state = block.captureGroup(at: 1, pattern: #"<div class=\"state\">(.*?)</div>"#)?.strippingHTML().trimmedNilIfEmpty
        let grade = block.captureGroup(at: 1, pattern: #"<div class=\"grade\">(.*?)</div>"#)?.strippingHTML().trimmedNilIfEmpty

        let choicePattern =
            #"<input type=\"radio\" name=\"[^\"]*_answer\" value=\"([^\"]+)\" id=\"([^\"]+)\"([^>]*)/?>"#
            + #"[\s\S]*?<div class=\"d-flex w-auto\" id=\"[^\"]+\"[^>]*>([\s\S]*?)</div>\s*</div>"#
        let choiceMatches = block.matches(pattern: choicePattern)

        let choices = choiceMatches.compactMap { match -> LMSQuizChoice? in
            guard let value = match.groups[safe: 0],
                  let id = match.groups[safe: 1],
                  let labelHTML = match.groups[safe: 3] else {
                return nil
            }
            let images = extractImageURLs(fromHTML: labelHTML)
            return LMSQuizChoice(id: id, value: value, labelHTML: labelHTML, images: images)
        }

        let selectedAnswer = block
            .captureGroup(at: 1, pattern: #"<input type=\"radio\" name=\"[^\"]*_answer\" value=\"([^\"]+)\"[^>]*checked=\"checked\""#)
            ?? block.captureGroup(at: 1, pattern: #"<input type=\"radio\" name=\"[^\"]*_answer\" id=\"[^\"]*-1\" value=\"(-1)\"[^>]*checked=\"checked\""#)

        return LMSQuizQuestion(
            id: questionContainerId,
            number: qno,
            state: state,
            grade: grade,
            sequenceFieldName: sequenceFieldName,
            sequenceValue: sequenceValue,
            flaggedFieldName: flaggedFieldName,
            flaggedValue: flaggedValue,
            textHTML: textHTML,
            textImages: textImages,
            answerFieldName: answerFieldName,
            selectedAnswer: selectedAnswer,
            choices: choices
        )
    }

    // swiftlint:disable:next function_body_length
    private func parseSummaryPage(html: String, finalURL: URL) throws -> LMSQuizSummaryPage {
        let title = html.captureGroup(at: 1, pattern: #"<h2>(.*?)</h2>"#)?.strippingHTML().trimmedNilIfEmpty ?? "Сводка теста"
        let courseTitle = html.captureGroup(at: 1, pattern: #"<h1>(.*?)</h1>"#)?
            .strippingHTML()
            .trimmedNilIfEmpty

        let summaryPattern =
            #"<tr class=\"quizsummary(\d+) [^\"]*\">[\s\S]*?<a href=\"([^\"]+)\"[^>]*>(\d+)</a>"#
            + #"[\s\S]*?<td class=\"cell c1 lastcol\"[^>]*>(.*?)</td>"#
        let statusMatches = html.matches(pattern: summaryPattern)
        let statusItems = statusMatches.compactMap { match -> LMSQuizSummaryItem? in
            guard let idText = match.groups[safe: 0],
                  let id = Int(idText),
                  let href = match.groups[safe: 1],
                  let questionNumberText = match.groups[safe: 2],
                  let questionNumber = Int(questionNumberText),
                  let statusRaw = match.groups[safe: 3] else {
                return nil
            }
            return LMSQuizSummaryItem(
                id: id,
                questionNumber: questionNumber,
                status: statusRaw.strippingHTML().trimmedNilIfEmpty ?? "-",
                url: self.absoluteURL(href)
            )
        }

        let finishFormPattern =
            #"(<form method=\"post\" action=\"https://lms\.bsuir\.by/mod/quiz/processattempt\.php\""#
            + #" id=\"frm-finishattempt\">[\s\S]*?</form>)"#
        let finishFormBlock = html.captureGroup(at: 1, pattern: finishFormPattern)
        let finishForm: LMSQuizForm?
        if let finishFormBlock,
           let finishAction = finishFormBlock.captureGroup(at: 1, pattern: #"action=\"([^\"]+)\""#).flatMap(self.absoluteURL) {
            finishForm = LMSQuizForm(actionURL: finishAction, method: "POST", fields: parseInputFields(in: finishFormBlock))
        } else {
            finishForm = nil
        }

        let returnFormBlock = html.captureGroup(at: 1, pattern: #"(<form method=\"post\" action=\"https://lms\.bsuir\.by/mod/quiz/attempt\.php\"[\s\S]*?</form>)"#)
        let returnForm: LMSQuizForm?
        if let returnFormBlock,
           let returnAction = returnFormBlock.captureGroup(at: 1, pattern: #"action=\"([^\"]+)\""#).flatMap(self.absoluteURL) {
            returnForm = LMSQuizForm(actionURL: returnAction, method: "POST", fields: parseInputFields(in: returnFormBlock))
        } else {
            returnForm = nil
        }

        let attemptId = (finishForm?.fields["attempt"] ?? returnForm?.fields["attempt"]).flatMap(Int.init) ??
            URLComponents(url: finalURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "attempt" })?.value.flatMap(Int.init) ?? 0

        let cmid = (finishForm?.fields["cmid"] ?? returnForm?.fields["cmid"])
            .flatMap(Int.init)

        let deadlineText = html.captureGroup(
            at: 1,
            pattern: #"<div class=\"submitbtns mdl-align\">\s*(.*?)\s*<div class=\"controls\">"#
        )?
        .strippingHTML()
        .trimmedNilIfEmpty

        return LMSQuizSummaryPage(
            title: title,
            courseTitle: courseTitle,
            attemptId: attemptId,
            cmid: cmid,
            statusItems: statusItems,
            finishForm: finishForm,
            returnForm: returnForm,
            deadlineText: deadlineText
        )
    }

    private func loadHTML(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 399).contains(http.statusCode) else {
            throw LMSError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw LMSError.invalidResponse
        }
        return html
    }

    private func submit(form: LMSQuizForm) async throws -> HTMLResponse {
        var requestURL = form.actionURL
        var request = URLRequest(url: requestURL)
        let method = form.method.uppercased()

        if method == "GET" {
            if var components = URLComponents(url: form.actionURL, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                for (key, value) in form.fields {
                    queryItems.append(URLQueryItem(name: key, value: value))
                }
                components.queryItems = queryItems
                requestURL = components.url ?? form.actionURL
                request = URLRequest(url: requestURL)
            }
            request.httpMethod = "GET"
        } else {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = percentEncoded(form.fields)
        }

        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 399).contains(http.statusCode) else {
            throw LMSError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw LMSError.invalidResponse
        }

        return HTMLResponse(html: html, finalURL: response.url ?? requestURL)
    }

    private func submitMultipart(form: LMSQuizForm) async throws -> HTMLResponse {
        var request = URLRequest(url: form.actionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = "----MyIISBoundary\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(fields: form.fields, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 399).contains(http.statusCode) else {
            throw LMSError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw LMSError.invalidResponse
        }

        return HTMLResponse(html: html, finalURL: response.url ?? form.actionURL)
    }

}

extension LMSQuizService {
    func openAttempt(url: URL) async throws -> LMSQuizScreenState {
        try await fetchScreen(url: url)
    }
}

private extension LMSQuizService {
    func multipartBody(fields: [String: String], boundary: String) -> Data {
        var data = Data()
        for (name, value) in fields {
            data.append(Data("--\(boundary)\r\n".utf8))
            data.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            data.append(Data("\(value)\r\n".utf8))
        }
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }

    func percentEncoded(_ fields: [String: String]) -> Data? {
        let bodyString = fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(bodyString.utf8)
    }

    func parseInputFields(in html: String) -> [String: String] {
        var fields: [String: String] = [:]
        for input in html.matches(pattern: #"<input[^>]*>"#) {
            guard let name = input.fullText.captureGroup(at: 1, pattern: #"name=\"([^\"]+)\""#) else { continue }
            let value = input.fullText.captureGroup(at: 1, pattern: #"value=\"([^\"]*)\""#) ?? ""
            fields[name.decodingHTMLEntities()] = value.decodingHTMLEntities()
        }
        return fields
    }

    func extractImageURLs(fromHTML html: String) -> [URL] {
        html.captureGroups(at: 1, pattern: #"<img[^>]*src=\"([^\"]+)\""#)
            .compactMap(self.absoluteURL)
    }

    func parsePreviousAttempts(from html: String) -> [LMSQuizPreviousAttempt] {
        guard html.contains("Ваши попытки") else { return [] }
        let cards = html.matches(pattern: #"<li class=\"col [\s\S]*?</li>"#)
        return cards.compactMap { card in
            let source = card.fullText
            let title = source.captureGroup(at: 1, pattern: #"<h4 class=\"card-title my-0\">(.*?)</h4>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
                ?? "Попытка"
            let state = source.captureGroup(at: 1, pattern: #"<th class=\"cell\" scope=\"row\">Состояние</th>\s*<td class=\"cell\">(.*?)</td>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
            let startedAt = source.captureGroup(at: 1, pattern: #"<th class=\"cell\" scope=\"row\">Тест начат</th>\s*<td class=\"cell\">(.*?)</td>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
            let finishedAt = source.captureGroup(at: 1, pattern: #"<th class=\"cell\" scope=\"row\">Завершен</th>\s*<td class=\"cell\">(.*?)</td>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
            let duration = source.captureGroup(at: 1, pattern: #"<th class=\"cell\" scope=\"row\">Затраченное время</th>\s*<td class=\"cell\">(.*?)</td>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
            let score = source.captureGroup(at: 1, pattern: #"<th class=\"cell\" scope=\"row\">Баллы</th>\s*<td class=\"cell\">(.*?)</td>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
            let grade = source.captureGroup(at: 1, pattern: #"<th class=\"cell\" scope=\"row\">Оценка</th>\s*<td class=\"cell\">([\s\S]*?)</td>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty
            let reviewMessage = source.captureGroup(at: 1, pattern: #"<span class=\"noreviewmessage\">(.*?)</span>"#)?
                .strippingHTML()
                .trimmedNilIfEmpty

            return LMSQuizPreviousAttempt(
                title: title,
                state: state,
                startedAt: startedAt,
                finishedAt: finishedAt,
                duration: duration,
                score: score,
                grade: grade,
                reviewMessage: reviewMessage
            )
        }
    }

    func absoluteURL(_ raw: String) -> URL? {
        let decoded = raw.decodingHTMLEntities()
        if let url = URL(string: decoded), url.scheme != nil {
            return url
        }
        return URL(string: decoded, relativeTo: URL(string: "https://lms.bsuir.by"))?.absoluteURL
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func strippingHTML() -> String {
        replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .decodingHTMLEntities()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
