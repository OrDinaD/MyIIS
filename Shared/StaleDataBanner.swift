import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StaleDataBanner: View {
    let lastUpdateTime: Date?
    var errorMessage: String?
    let action: () -> Void

    @State private var showingErrorDetails = false

    var body: some View {
        Button {
            showingErrorDetails = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("error_server_unavailable", value: "Сервер недоступен", comment: ""))
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
                errorMessage: errorMessage ?? "Сервер недоступен. Детали ниже.",
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

struct ErrorDetailsView: View {
    let errorMessage: String
    let lastUpdateTime: Date?
    let retryAction: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var serverStatuses: [BSUIRServerStatus] = []
    @State private var isLoadingDiagnostics = false
    @State private var copyLabel = "Скопировать"

    private static let monitoredServers: [(name: String, url: String)] = [
        ("ИИС", "https://iis.bsuir.by/api/v1"),
        ("LMS", "https://lms.bsuir.by"),
        ("Портал БГУИР", "https://www.bsuir.by")
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
                        Text(
                            "Рекомендуется отключить VPN и использовать сеть eduroam. "
                                + "Это снижает риск блокировки/таймаутов при доступе к сервисам БГУИР."
                        )
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
                    Button("Обновить") {
                        retryAction()
                        Task { await reloadDiagnostics() }
                    }
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
        isLoadingDiagnostics = true
        let statuses = await collectServerStatuses()
        serverStatuses = statuses
        isLoadingDiagnostics = false
    }

    private func collectServerStatuses() async -> [BSUIRServerStatus] {
        await withTaskGroup(of: BSUIRServerStatus.self) { group in
            for server in Self.monitoredServers {
                group.addTask {
                    await probeServer(name: server.name, rawURL: server.url)
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

    private func probeServer(name: String, rawURL: String) async -> BSUIRServerStatus {
        guard let url = URL(string: rawURL) else {
            return makeInvalidURLStatus(name: name, rawURL: rawURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        let startedAt = Date()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return makeNonHTTPStatus(name: name, rawURL: rawURL)
            }

            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            let isAvailable = (200 ... 399).contains(http.statusCode)
            let summary = isAvailable ? "Доступен" : "Недоступен"
            let detail = isAvailable
                ? "HTTP \(http.statusCode), \(elapsedMs) мс"
                : "HTTP \(http.statusCode), \(elapsedMs) мс — сервер вернул ошибку"

            return BSUIRServerStatus(
                name: name,
                url: rawURL,
                summary: summary,
                detail: detail,
                tint: isAvailable ? .green : .red
            )
        } catch {
            if let urlError = error as? URLError {
                return makeAccessErrorStatus(name: name, rawURL: rawURL, detail: "URLError \(urlError.code.rawValue) (\(urlError.code))")
            }

            let nsError = error as NSError
            return makeAccessErrorStatus(name: name, rawURL: rawURL, detail: "\(nsError.domain) / \(nsError.code)")
        }
    }

    private func makeInvalidURLStatus(name: String, rawURL: String) -> BSUIRServerStatus {
        BSUIRServerStatus(name: name, url: rawURL, summary: "Ошибка URL", detail: "Некорректный URL для проверки.", tint: .red)
    }

    private func makeNonHTTPStatus(name: String, rawURL: String) -> BSUIRServerStatus {
        BSUIRServerStatus(name: name, url: rawURL, summary: "Нет HTTP-ответа", detail: "Сервер ответил не-HTTP протоколом.", tint: .orange)
    }

    private func makeAccessErrorStatus(name: String, rawURL: String, detail: String) -> BSUIRServerStatus {
        BSUIRServerStatus(name: name, url: rawURL, summary: "Нет доступа", detail: detail, tint: .red)
    }

    private var technicalDetailsText: String {
        var lines: [String] = [
            "Ошибка:",
            errorMessage,
            "",
            "Проверка серверов выполняется запросом HEAD с timeout 8 секунд.",
            "Если ошибка повторяется: отключите VPN и попробуйте сеть eduroam."
        ]

        if !serverStatuses.isEmpty {
            lines.append("")
            lines.append("Последняя проверка серверов:")
            lines.append(contentsOf: serverStatuses.map { "\($0.name): \($0.summary) (\($0.detail))" })
        }

        return lines.joined(separator: "\n")
    }

    private func copyDiagnosticsToClipboard() {
        var payload: [String] = [
            "=== Ошибка ===",
            errorMessage,
            "",
            "=== Доступность серверов БГУИР ==="
        ]

        payload.append(contentsOf: serverStatuses.map { "\($0.name): \($0.summary) | \($0.detail) | \($0.url)" })
        payload.append("")
        payload.append("=== Рекомендация ===")
        payload.append("Отключить VPN и использовать сеть eduroam")
        payload.append("")
        payload.append("=== Технические детали ===")
        payload.append(technicalDetailsText)

#if canImport(UIKit)
        UIPasteboard.general.string = payload.joined(separator: "\n")
#endif
        copyLabel = "Скопировано"

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            copyLabel = "Скопировать"
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
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}
