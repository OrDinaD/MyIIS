//
//  ScheduleServerMetricsView.swift
//  MyIIS
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ==============================================================================
// MARK: - [DEBUG_TELEMETRY_MODULE] UI ЭКРАН МЕТРИК И ДИАГНОСТИКИ
// ==============================================================================

struct ScheduleServerMetricsView: View {
    @ObservedObject private var tracker = ScheduleServerMetricsTracker.shared
    @AppStorage(
        ScheduleServerConfiguration.serverDefaultsKey,
        store: ScheduleServerConfiguration.defaults
    )
    private var selectedServerRaw = ScheduleAPIServer.auto.rawValue

    @State private var isClearConfirmationPresented = false
    @State private var isReportCopied = false
    @State private var selectedRecordForDetails: ScheduleServerMetricRecord?

    private var selectedServer: Binding<ScheduleAPIServer> {
        Binding(
            get: { ScheduleAPIServer(rawValue: selectedServerRaw) ?? .auto },
            set: { selectedServerRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            networkEnvironmentSection
            exportAndDiagnosticsSection
            serverSelectionSection
            livePingSection
            summaryComparisonSection
            classHoursAnalysisSection
            recentRecordsSection
        }
        .navigationTitle(NSLocalizedString("server_metrics_title", value: "Метрики и диагностика", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !tracker.records.isEmpty {
                        ShareLink(
                            item: tracker.generateDetailedReport(),
                            subject: Text("Диагностический отчет сети MyIIS"),
                            message: Text("Сетевой отчет MyIIS")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            isClearConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            NSLocalizedString("server_metrics_clear_title", value: "Очистить историю замеров?", comment: ""),
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("server_metrics_clear_action", value: "Очистить", comment: ""), role: .destructive) {
                tracker.clearAll()
            }
            Button(NSLocalizedString("common_cancel", value: "Отмена", comment: ""), role: .cancel) {}
        }
        .sheet(item: $selectedRecordForDetails) { record in
            recordDetailSheet(record)
        }
    }

    // MARK: - Network Environment Section

    private var networkEnvironmentSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: networkIconName(tracker.currentNetwork.connectionType))
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tracker.currentNetwork.connectionType)
                            .font(.headline)

                        Text("Текущее соединение устройства")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if tracker.currentNetwork.isVPNActive {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                            Text("VPN")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.slash")
                            Text("Без VPN")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                    }
                }

                if tracker.currentNetwork.isConstrained || tracker.currentNetwork.isExpensive {
                    HStack(spacing: 6) {
                        if tracker.currentNetwork.isConstrained {
                            Label("Low Data Mode", systemImage: "leaf.fill")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        }
                        if tracker.currentNetwork.isExpensive {
                            Label("Лимитная сеть", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Сетевое окружение")
        } footer: {
            Text("Телеметрия отслеживает поведение сервера на Wi-Fi, мобильных данных и при включенном VPN для выявления узких мест.")
        }
    }

    // MARK: - Export & Diagnostics Section

    private var exportAndDiagnosticsSection: some View {
        Section {
            Button {
                copyReportToClipboard()
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isReportCopied ? "Отчет скопирован в буфер!" : "Скопировать полный отчет")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isReportCopied ? .green : .primary)
                            Text("Сводка пингов, сравнение сетей, VPN и лог для анализа")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: isReportCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .foregroundStyle(isReportCopied ? .green : .blue)
                            .font(.title3)
                    }

                    Spacer()

                    if isReportCopied {
                        Text("Готово")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 2)
            }

            ShareLink(
                item: tracker.generateDetailedReport(),
                subject: Text("Диагностический отчет сети MyIIS"),
                message: Text("Сетевой отчет MyIIS")
            ) {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Поделиться отчетом...")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Отправить текстовый файл или заметку")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.purple)
                            .font(.title3)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Экспорт телеметрии")
        } footer: {
            Text("Скопируйте отчет и отправьте его разработчику в чат — в нем собраны все задержки, статус-коды, влияние VPN и размер трафика.")
        }
    }

    // MARK: - Server Selection

    private var serverSelectionSection: some View {
        Section {
            Picker(
                NSLocalizedString("server_metrics_active_server", value: "Активный сервер", comment: ""),
                selection: selectedServer
            ) {
                ForEach(ScheduleAPIServer.allCases) { server in
                    Label(server.localizedTitle, systemImage: server.iconName)
                        .tag(server)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: (selectedServer.wrappedValue).iconName)
                        .foregroundStyle(.tint)
                    Text((selectedServer.wrappedValue).shortTitle)
                        .fontWeight(.semibold)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text((selectedServer.wrappedValue).host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text((selectedServer.wrappedValue).subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text(NSLocalizedString("server_metrics_config_header", value: "Выбор сервера", comment: ""))
        } footer: {
            Text(NSLocalizedString("server_metrics_config_footer", value: "В режиме «Авто» приложение делает запросы к быстрому шлюзу и автоматически переключается на БГУИР, если шлюз недоступен.", comment: ""))
        }
    }

    // MARK: - Live Ping Benchmark

    private var livePingSection: some View {
        Section {
            Button {
                Task {
                    _ = await tracker.runLiveBenchmark()
                }
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("server_metrics_ping_now", value: "Замерить скорость прямо сейчас", comment: ""))
                                .fontWeight(.medium)
                            Text(NSLocalizedString("server_metrics_ping_desc", value: "Параллельный замер /current-week с обоих серверов", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        if tracker.isBenchmarking {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.purple)
                        } else {
                            Image(systemName: "bolt.badge.clock.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    Spacer()
                }
            }
            .disabled(tracker.isBenchmarking)

            if let result = tracker.lastBenchmarkResult {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Шлюз MyIIS")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            if let g = result.gatewayDurationMs {
                                Text("\(g) мс")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.green)
                            } else {
                                Text(result.gatewayError ?? "Ошибка")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        if let speedup = result.speedupFactor {
                            VStack {
                                Text(String(format: "%.1f×", speedup))
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(.purple)
                                Text("разгон")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Официальный БГУИР")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            if let o = result.officialDurationMs {
                                Text("\(o) мс")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.orange)
                            } else {
                                Text(result.officialError ?? "Ошибка")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(NSLocalizedString("server_metrics_ping_header", value: "Тест скорости (Ping)", comment: ""))
        }
    }

    // MARK: - Summary Comparison

    private var summaryComparisonSection: some View {
        Section {
            HStack(spacing: 12) {
                serverSummaryCard(
                    title: "Шлюз MyIIS",
                    icon: "bolt.horizontal.fill",
                    color: .green,
                    avgDuration: tracker.averageDuration(for: "gateway"),
                    minDuration: tracker.minDuration(for: "gateway"),
                    maxDuration: tracker.maxDuration(for: "gateway"),
                    successRate: tracker.successRate(for: "gateway"),
                    count: tracker.totalRequests(for: "gateway"),
                    avgBytes: tracker.averageResponseBytes(for: "gateway")
                )

                serverSummaryCard(
                    title: "БГУИР (Офиц.)",
                    icon: "building.columns.fill",
                    color: .blue,
                    avgDuration: tracker.averageDuration(for: "official"),
                    minDuration: tracker.minDuration(for: "official"),
                    maxDuration: tracker.maxDuration(for: "official"),
                    successRate: tracker.successRate(for: "official"),
                    count: tracker.totalRequests(for: "official"),
                    avgBytes: tracker.averageResponseBytes(for: "official")
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)

            if let speedup = tracker.speedupComparison {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text(speedup)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("на основе \(tracker.records.count) замеров")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(NSLocalizedString("server_metrics_summary_header", value: "Сводная статистика работы", comment: ""))
        }
    }

    private func serverSummaryCard(
        title: String,
        icon: String,
        color: Color,
        avgDuration: Double?,
        minDuration: Int?,
        maxDuration: Int?,
        successRate: Double,
        count: Int,
        avgBytes: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            if let avg = avgDuration {
                Text("\(Int(avg)) мс")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(latencyColor(Int(avg)))
                if let min = minDuration, let max = maxDuration {
                    Text("\(min) – \(max) мс")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Успешно:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f%%", successRate))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(successRate > 95 ? .green : .orange)
                Spacer()
                Text("\(count) зап.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let avgBytes {
                HStack {
                    Text("Трафик:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(avgBytes), countStyle: .file))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Class Hours Analysis

    private var classHoursAnalysisSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Во время пар (08:00 - 19:30)", systemImage: "clock.badge.exclamationmark.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Шлюз:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let gClass = tracker.classHoursAverageDuration(for: "gateway") {
                            Text("\(Int(gClass)) мс")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(latencyColor(Int(gClass)))
                        } else {
                            Text("нет данных")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("БГУИР:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let oClass = tracker.classHoursAverageDuration(for: "official") {
                            Text("\(Int(oClass)) мс")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(latencyColor(Int(oClass)))
                        } else {
                            Text("нет данных")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                HStack {
                    Label("Вне пар (вечер / ночь / выходные)", systemImage: "moon.stars.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.indigo)
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Шлюз:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let gOff = tracker.offHoursAverageDuration(for: "gateway") {
                            Text("\(Int(gOff)) мс")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(latencyColor(Int(gOff)))
                        } else {
                            Text("нет данных")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("БГУИР:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let oOff = tracker.offHoursAverageDuration(for: "official") {
                            Text("\(Int(oOff)) мс")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(latencyColor(Int(oOff)))
                        } else {
                            Text("нет данных")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(NSLocalizedString("server_metrics_class_hours_header", value: "Нагрузка по времени суток", comment: ""))
        } footer: {
            Text(NSLocalizedString("server_metrics_class_hours_footer", value: "Серверы университета испытывают пиковую нагрузку во время занятий. Эта статистика поможет оценить стабильность шлюза в пике.", comment: ""))
        }
    }

    // MARK: - Recent Records

    private var recentRecordsSection: some View {
        Section {
            if tracker.records.isEmpty {
                Text(NSLocalizedString("server_metrics_empty", value: "Замеров пока нет. Запросы будут фиксироваться автоматически при использовании расписания.", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(tracker.records.prefix(40)) { record in
                    Button {
                        selectedRecordForDetails = record
                    } label: {
                        recordRow(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text(NSLocalizedString("server_metrics_recent_header", value: "История запросов", comment: ""))
                Spacer()
                if !tracker.records.isEmpty {
                    Text("\(tracker.records.count) всего")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func recordRow(_ record: ScheduleServerMetricRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(record.server == "gateway" ? Color.green : Color.blue)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.serverDisplayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if record.isVPN {
                        Text("VPN")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }

                    if record.isClassHour {
                        Text("Пары")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 4) {
                    Text(record.endpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime(record.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let size = record.formattedResponseSize {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let enc = record.contentEncoding {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(enc)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if record.isSuccess {
                    Text("\(record.durationMs) мс")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(latencyColor(record.durationMs))
                    Text("HTTP \(record.httpStatusCode)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Сбой")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.red)
                    Text(record.errorMessage ?? "Error")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail Sheet

    private func recordDetailSheet(_ record: ScheduleServerMetricRecord) -> some View {
        NavigationStack {
            List {
                Section("Основное") {
                    LabeledContent("Сервер", value: record.serverDisplayName)
                    LabeledContent("Эндпоинт", value: record.endpoint)
                    LabeledContent("Время", value: formattedTime(record.timestamp))
                    LabeledContent("Задержка", value: "\(record.durationMs) мс")
                    LabeledContent("HTTP Статус", value: "\(record.httpStatusCode)")
                    LabeledContent("Успешно", value: record.isSuccess ? "Да" : "Нет")
                    if let err = record.errorMessage {
                        LabeledContent("Ошибка", value: err)
                    }
                }

                Section("Сетевое окружение") {
                    LabeledContent("Тип сети", value: record.connectionType)
                    LabeledContent("VPN", value: record.isVPN ? "Активен" : "Выключен")
                    LabeledContent("Лимитная сеть", value: record.isExpensive ? "Да" : "Нет")
                    LabeledContent("Low Data Mode", value: record.isConstrained ? "Включен" : "Выключен")
                    LabeledContent("Учебные часы", value: record.isClassHour ? "Да (08:00-19:30)" : "Вне занятий")
                }

                Section("HTTP Заголовки и данные") {
                    if let size = record.formattedResponseSize {
                        LabeledContent("Размер тела", value: size)
                    }
                    if let enc = record.contentEncoding {
                        LabeledContent("Content-Encoding", value: enc)
                    }
                    if let timing = record.serverTiming {
                        LabeledContent("Server-Timing", value: timing)
                    }
                    if let cache = record.cacheControl {
                        LabeledContent("Cache-Control", value: cache)
                    }
                    if let url = record.fullURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Полный URL:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(url)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Детали запроса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        selectedRecordForDetails = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func copyReportToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = tracker.generateDetailedReport()
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        #endif

        withAnimation {
            isReportCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isReportCopied = false
            }
        }
    }

    private func networkIconName(_ type: String) -> String {
        if type.contains("Wi-Fi") {
            return "wifi"
        } else if type.contains("Сотовая") || type.contains("Cellular") {
            return "antenna.radiowaves.left.and.right"
        } else if type.contains("Ethernet") {
            return "cable.connector"
        } else {
            return "network"
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 250 {
            return .green
        } else if ms < 600 {
            return .orange
        } else {
            return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
