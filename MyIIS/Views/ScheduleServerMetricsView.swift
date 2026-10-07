//
//  ScheduleServerMetricsView.swift
//  MyIIS
//

import SwiftUI

struct ScheduleServerMetricsView: View {
    @ObservedObject private var tracker = ScheduleServerMetricsTracker.shared
    @AppStorage(
        ScheduleServerConfiguration.serverDefaultsKey,
        store: ScheduleServerConfiguration.defaults
    )
    private var selectedServerRaw = ScheduleAPIServer.auto.rawValue

    @State private var isClearConfirmationPresented = false

    private var selectedServer: Binding<ScheduleAPIServer> {
        Binding(
            get: { ScheduleAPIServer(rawValue: selectedServerRaw) ?? .auto },
            set: { selectedServerRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            serverSelectionSection
            livePingSection
            summaryComparisonSection
            classHoursAnalysisSection
            recentRecordsSection
        }
        .navigationTitle(NSLocalizedString("server_metrics_title", value: "Метрики серверов", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !tracker.records.isEmpty {
                    Button(role: .destructive) {
                        isClearConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
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
                    successRate: tracker.successRate(for: "gateway"),
                    count: tracker.totalRequests(for: "gateway")
                )

                serverSummaryCard(
                    title: "БГУИР (Офиц.)",
                    icon: "building.columns.fill",
                    color: .blue,
                    avgDuration: tracker.averageDuration(for: "official"),
                    successRate: tracker.successRate(for: "official"),
                    count: tracker.totalRequests(for: "official")
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
        successRate: Double,
        count: Int
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
            Text(NSLocalizedString("server_metrics_class_hours_footer", value: "Серверы университета испытывают пиковую нагрузку во время занятий. Эта статистика поможет определить оптимальный порог для умного авто-режима.", comment: ""))
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
                ForEach(tracker.records.prefix(30)) { record in
                    recordRow(record)
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
                    if record.isClassHour {
                        Text("Пары")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 4) {
                    Text(record.endpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime(record.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
