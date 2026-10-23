import SwiftUI

struct ScheduleServerInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var official: ScheduleServerAvailability?
    @State private var gateway: ScheduleServerAvailability?
    @State private var checkedAt: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Доступность сейчас") {
                    availabilityRow("БГУИР", host: "iis.bsuir.by", result: official)
                    availabilityRow("Сервер MyIIS", host: "bsuir.ordinad.xyz", result: gateway)
                    if let checkedAt {
                        Text("Проверено: \(checkedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Пинг здесь — время ответа API по HTTPS, включая установку соединения. Проверка выполняется при открытии этого окна; скорость зависит от вашей сети.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Как устроен сервер MyIIS") {
                    Text(
                        "Сервер получает публичное расписание БГУИР, сохраняет его в кэше и отдаёт приложению. Он обслуживает расписание и " +
                        "связанные справочники и фотографии преподавателей."
                    )
                    Text("Если сервер MyIIS не отвечает, приложение автоматически обращается в БГУИР. Уже загруженное расписание и фотографии доступны из кэша.")
                }
                Section("Аккаунт и конфиденциальность") {
                    Label("Без доступа к аккаунту ИИС", systemImage: "lock.shield")
                    Text("Вход, пароль, сессия, оценки и личный кабинет не проходят через сервер MyIIS. Эти запросы идут напрямую в БГУИР.")
                    Text(
                        "Для уведомлений об изменениях сервер хранит номер группы, технический токен устройства Apple и среду доставки. Это нужно " +
                        "для отправки пушей. Также хостинг обрабатывает технические данные соединения, например IP-адрес. Поэтому обещать полное " +
                        "отсутствие обработки данных было бы неверно."
                    )
                }
                Section("Для кого и зачем") {
                    Label("Уведомления об изменении пар", systemImage: "bell.badge")
                    Text(
                        "Сервер периодически проверяет расписание группы и может отправлять уведомления через Apple даже когда приложение " +
                        "закрыто. Это уменьшает зависимость от фоновых проверок iOS; доставка зависит от сети и разрешения на уведомления."
                    )
                    Label("Расписание в виджете", systemImage: "rectangle.on.rectangle")
                    Text("Кэш сервера помогает виджету получить расписание, когда сайт БГУИР отвечает медленно. Частоту обновлений виджета определяет iOS.")
                    Text(
                        "Подойдёт тем, у кого БГУИР часто недоступен или кто хочет использовать серверную проверку изменений. Выбор источника " +
                        "расписания не меняет настройки уведомлений."
                    )
                }
            }
            .navigationTitle("О серверах расписания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .task { await checkAvailability() }
        }
    }

    private func availabilityRow(
        _ title: String, host: String, result: ScheduleServerAvailability?
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            Text(host).font(.caption).foregroundStyle(.secondary)
            if let result {
                Label(
                    result.available ? "Доступен · \(result.milliseconds) мс" : result.message,
                    systemImage: result.available ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .foregroundStyle(result.available ? Color.green : Color.secondary)
            } else {
                ProgressView("Проверяем…")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func checkAvailability() async {
        async let officialResult = ScheduleServerAvailability.check(baseURL: ScheduleServerConfiguration.officialBaseURL)
        async let gatewayResult = ScheduleServerAvailability.check(baseURL: ScheduleServerConfiguration.gatewayBaseURL)
        let results = await (officialResult, gatewayResult)
        guard !Task.isCancelled else { return }
        official = results.0
        gateway = results.1
        checkedAt = Date()
    }
}

struct ScheduleServerAvailability: Sendable {
    let available: Bool
    let milliseconds: Int
    let message: String

    nonisolated static func check(baseURL: URL) async -> Self {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(
            url: baseURL.appendingPathComponent("schedule/current-week"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.timeoutInterval = 5
        let started = ContinuousClock.now
        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = started.duration(to: .now).components
            let milliseconds = Int(elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000)
            guard let http = response as? HTTPURLResponse else {
                return Self(available: false, milliseconds: milliseconds, message: "Некорректный ответ")
            }
            guard (200...299).contains(http.statusCode) else {
                return Self(available: false, milliseconds: milliseconds, message: "Недоступен · HTTP \(http.statusCode)")
            }
            guard let week = try? JSONDecoder().decode(Int.self, from: data), (1...4).contains(week) else {
                return Self(available: false, milliseconds: milliseconds, message: "Некорректный ответ API")
            }
            return Self(available: true, milliseconds: milliseconds, message: "Доступен")
        } catch {
            return Self(
                available: false, milliseconds: 0,
                message: (error as? URLError)?.code == .timedOut ? "Не ответил за 5 секунд" : "Недоступен в этой сети"
            )
        }
    }
}

#Preview {
    ScheduleServerInfoView()
}
