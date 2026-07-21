import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StaleDataBanner: View {
    let lastUpdateTime: Date?
    var errorMessage: String?
    let action: () async -> Void

    @State private var showingErrorDetails = false

    var body: some View {
        Button {
            showingErrorDetails = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Не удалось обновить данные")
                        .font(.subheadline.weight(.semibold))

                    if let lastUpdateTime = lastUpdateTime {
                        Text(
                            String(
                                format: NSLocalizedString(
                                    "error_stale_data_with_time",
                                    value: "Данные могут быть устаревшими. Последнее обновление: %@",
                                    comment: ""
                                ),
                                lastUpdateTime.staleDataFormattedDateTime
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(NSLocalizedString("error_stale_data", value: "Данные могут быть устаревшими.", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingErrorDetails) {
            ErrorDetailsView(
                errorMessage: errorMessage ?? String(localized: "Сервер недоступен. Детали ниже."),
                lastUpdateTime: lastUpdateTime,
                retryAction: action
            )
        }
    }
}

private struct BSUIRServerStatus: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let summary: String
    let detail: String
    let tint: Color
}

private struct MonitoredServer {
    let name: String
    let url: String
    let method: String
}

private func makeServerStatus(
    for statusCode: Int,
    server: MonitoredServer,
    elapsedMs: Int
) -> BSUIRServerStatus {
    let responseDetail = "HTTP \(statusCode), \(elapsedMs) мс"

    switch statusCode {
    case 200 ... 399:
        return BSUIRServerStatus(
            name: server.name,
            url: server.url,
            summary: String(localized: "Доступен"),
            detail: responseDetail,
            tint: .green
        )
    case 401, 403:
        return BSUIRServerStatus(
            name: server.name,
            url: server.url,
            summary: String(localized: "Доступен"),
            detail: String(format: String(localized: "%@ — требуется авторизация"), responseDetail),
            tint: .orange
        )
    case 405 where server.method == "HEAD":
        return BSUIRServerStatus(
            name: server.name,
            url: server.url,
            summary: String(localized: "Доступен"),
            detail: String(format: String(localized: "%@ — сервер не поддерживает HEAD"), responseDetail),
            tint: .orange
        )
    case 400 ... 499:
        return BSUIRServerStatus(
            name: server.name,
            url: server.url,
            summary: String(localized: "Ошибка API"),
            detail: String(format: String(localized: "%@ — endpoint вернул ошибку"), responseDetail),
            tint: .orange
        )
    default:
        return BSUIRServerStatus(
            name: server.name,
            url: server.url,
            summary: String(localized: "Недоступен"),
            detail: String(format: String(localized: "%@ — ошибка сервера"), responseDetail),
            tint: .red
        )
    }
}

struct ErrorDetailsView: View {
    let errorMessage: String
    let lastUpdateTime: Date?
    let retryAction: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var serverStatuses: [BSUIRServerStatus] = []
    @State private var isLoadingDiagnostics = false
    @State private var isRetrying = false
    @State private var copyLabel = String(localized: "Скопировать")

    private static let monitoredServers: [MonitoredServer] = [
        MonitoredServer(
            name: "ИИС API",
            url: "https://iis.bsuir.by/api/v1/faculties",
            method: "GET"
        ),
        MonitoredServer(name: "LMS", url: "https://lms.bsuir.by", method: "HEAD"),
        MonitoredServer(name: String(localized: "Портал БГУИР"), url: "https://www.bsuir.by", method: "HEAD")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Код ошибки / Подробности:")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Доступность серверов БГУИР")
                            .font(.headline)

                        if isLoadingDiagnostics && serverStatuses.isEmpty {
                            ProgressView("Проверяем серверы...")
                                .font(.subheadline)
                        }

                        ForEach(serverStatuses) { status in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Circle()
                                        .fill(status.tint)
                                        .frame(width: 8, height: 8)
                                    Text(status.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(status.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(status.url)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                Text(status.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Рекомендации по сети")
                            .font(.headline)
                        Text("Рекомендуется отключить VPN и использовать сеть eduroam. Это снижает риск блокировки/таймаутов при доступе к сервисам БГУИР.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Технические детали")
                            .font(.headline)
                        Text(technicalDetailsText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }

                    if let lastUpdateTime {
                        Text("Последнее успешное обновление данных:\n\(lastUpdateTime.staleDataFormattedDateTime)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Детали ошибки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        guard !isRetrying else { return }
                        Task {
                            isRetrying = true
                            await retryAction()
                            await reloadDiagnostics()
                            isRetrying = false
                        }
                    } label: {
                        if isRetrying {
                            ProgressView()
                                .accessibilityLabel("Обновление данных")
                        } else {
                            Text("Обновить")
                        }
                    }
                    .disabled(isRetrying)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(copyLabel) {
                        copyDiagnosticsToClipboard()
                    }
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await reloadDiagnostics()
        }
    }

    private func reloadDiagnostics() async {
        guard !isLoadingDiagnostics else { return }

        isLoadingDiagnostics = true
        let statuses = await collectServerStatuses()
        guard !Task.isCancelled else {
            isLoadingDiagnostics = false
            return
        }
        serverStatuses = statuses
        isLoadingDiagnostics = false
    }

    private func collectServerStatuses() async -> [BSUIRServerStatus] {
        await withTaskGroup(of: BSUIRServerStatus.self) { group in
            for server in Self.monitoredServers {
                group.addTask {
                    await probeServer(server)
                }
            }

            var result: [BSUIRServerStatus] = []
            for await status in group {
                result.append(status)
            }

            return result.sorted { lhs, rhs in
                let leftIndex = Self.monitoredServers.firstIndex(where: { $0.name == lhs.name }) ?? 0
                let rightIndex = Self.monitoredServers.firstIndex(where: { $0.name == rhs.name }) ?? 0
                return leftIndex < rightIndex
            }
        }
    }

    private func probeServer(_ server: MonitoredServer) async -> BSUIRServerStatus {
        guard let url = URL(string: server.url) else {
            return makeInvalidURLStatus(name: server.name, rawURL: server.url)
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 8
        )
        request.httpMethod = server.method
        if server.method == "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        let startedAt = Date()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return makeNonHTTPStatus(name: server.name, rawURL: server.url)
            }

            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            return makeServerStatus(
                for: http.statusCode,
                server: server,
                elapsedMs: elapsedMs
            )
        } catch {
            if error is CancellationError {
                return makeAccessErrorStatus(
                    name: server.name,
                    rawURL: server.url,
                    detail: String(localized: "Проверка отменена")
                )
            }
            if let urlError = error as? URLError {
                return makeAccessErrorStatus(
                    name: server.name,
                    rawURL: server.url,
                    detail: "URLError \(urlError.code.rawValue) (\(urlError.code))"
                )
            }

            let nsError = error as NSError
            return makeAccessErrorStatus(
                name: server.name,
                rawURL: server.url,
                detail: "\(nsError.domain) / \(nsError.code)"
            )
        }
    }

    private func makeInvalidURLStatus(name: String, rawURL: String) -> BSUIRServerStatus {
        BSUIRServerStatus(
            name: name,
            url: rawURL,
            summary: String(localized: "Ошибка URL"),
            detail: String(localized: "Некорректный URL для проверки."),
            tint: .red
        )
    }

    private func makeNonHTTPStatus(name: String, rawURL: String) -> BSUIRServerStatus {
        BSUIRServerStatus(
            name: name,
            url: rawURL,
            summary: String(localized: "Нет HTTP-ответа"),
            detail: String(localized: "Сервер ответил не-HTTP протоколом."),
            tint: .orange
        )
    }

    private func makeAccessErrorStatus(name: String, rawURL: String, detail: String) -> BSUIRServerStatus {
        BSUIRServerStatus(
            name: name,
            url: rawURL,
            summary: String(localized: "Нет доступа"),
            detail: detail,
            tint: .red
        )
    }

    private var technicalDetailsText: String {
        var lines: [String] = [
            String(localized: "Ошибка:"),
            errorMessage,
            "",
            String(localized: "ИИС проверяется через рабочий API endpoint, остальные серверы — лёгким HEAD-запросом с timeout 8 секунд."),
            String(localized: "Если ошибка повторяется: отключите VPN и попробуйте сеть eduroam.")
        ]

        if !serverStatuses.isEmpty {
            lines.append("")
            lines.append(String(localized: "Последняя проверка серверов:"))
            lines.append(contentsOf: serverStatuses.map { "\($0.name): \($0.summary) (\($0.detail))" })
        }

        return lines.joined(separator: "\n")
    }

    private func copyDiagnosticsToClipboard() {
        var payload: [String] = [
            String(localized: "=== Ошибка ==="),
            errorMessage,
            "",
            String(localized: "=== Доступность серверов БГУИР ===")
        ]

        payload.append(contentsOf: serverStatuses.map { "\($0.name): \($0.summary) | \($0.detail) | \($0.url)" })
        payload.append("")
        payload.append(String(localized: "=== Рекомендация ==="))
        payload.append(String(localized: "Отключить VPN и использовать сеть eduroam"))
        payload.append("")
        payload.append(String(localized: "=== Технические детали ==="))
        payload.append(technicalDetailsText)

#if canImport(UIKit)
        UIPasteboard.general.string = payload.joined(separator: "\n")
#endif
        copyLabel = String(localized: "Скопировано")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            copyLabel = String(localized: "Скопировать")
        }
    }
}

extension Date {
    var staleDataFormattedDateTime: String {
        DateFormatter.staleDataDateTimeFormatter.string(from: self)
    }
}

private extension DateFormatter {
    static let staleDataDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}
