//
//  FreeAuditoriesView.swift
//  MyIIS
//

import SwiftUI

@MainActor
struct FreeAuditoriesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBuilding: BSUIRBuilding = .b4
    @State private var selectedSlot: Int = LessonTimeSlot.currentSlot()
    @State private var selectedDay: String = Self.currentDayName()
    @State private var weekNumber: Int = 1
    @State private var searchQuery: String = ""

    @State private var response: FreeAuditoriesResponse?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let service = FreeAuditoriesService.shared

    private static let daysOfWeek = [
        "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                buildingPicker
                slotAndDayBar

                Divider()

                if isLoading && response == nil {
                    loadingView
                } else if let error = errorMessage, response == nil {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle(NSLocalizedString("free_auditories_title", value: "Свободные аудитории", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common_close", value: "Закрыть", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text(NSLocalizedString("free_auditories_search_prompt", value: "Номер аудитории...", comment: ""))
            )
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Subviews

    private var buildingPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BSUIRBuilding.allCases) { building in
                    Button {
                        if selectedBuilding != building {
                            selectedBuilding = building
                            Task { await loadData() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.caption2)
                            Text(building.displayName)
                                .font(.subheadline.weight(selectedBuilding == building ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedBuilding == building
                                ? Color.purple
                                : Color(uiColor: .secondarySystemFill),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedBuilding == building ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var slotAndDayBar: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Пара", selection: $selectedSlot) {
                    ForEach(LessonTimeSlot.allSlots) { slot in
                        Text("\(slot.title) (\(slot.timeIntervalString))").tag(slot.slot)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.purple)
                        .font(.caption)
                    if let slot = LessonTimeSlot.allSlots.first(where: { $0.slot == selectedSlot }) {
                        Text("\(slot.title) (\(slot.timeIntervalString))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
            .onChange(of: selectedSlot) {
                Task { await loadData() }
            }

            Spacer()

            Menu {
                Picker("День", selection: $selectedDay) {
                    ForEach(Self.daysOfWeek, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text(selectedDay)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
            .onChange(of: selectedDay) {
                Task { await loadData() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let resp = response {
                    statusSummaryCard(resp)
                    auditoriesGrid(resp)
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func statusSummaryCard(_ resp: FreeAuditoriesResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Свободно: \(filteredAuditories(resp.freeAuditories).count)")
                        .font(.headline.weight(.semibold))
                }
                Text("\(resp.building) корпус • \(resp.day) • \(resp.timeSlot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(resp.totalAuditories)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.purple)
                Text("всего ауд.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func auditoriesGrid(_ resp: FreeAuditoriesResponse) -> some View {
        let items = filteredAuditories(resp.freeAuditories)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Свободные кабинеты (\(items.count))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "door.left.hand.closed")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Нет свободных аудиторий по заданным параметрам")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(items, id: \.self) { aud in
                        auditoryBadge(name: aud)
                    }
                }
            }
        }
    }

    private func auditoryBadge(name: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Поиск свободных аудиторий...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Повторить") {
                Task { await loadData() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Logic

    private func filteredAuditories(_ list: [String]) -> [String] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return list }
        return list.filter { $0.lowercased().contains(query) }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let res = try await service.fetchFreeAuditories(
                building: selectedBuilding.rawValue,
                day: selectedDay,
                slot: selectedSlot,
                week: weekNumber
            )
            self.response = res
        } catch {
            self.errorMessage = "Не удалось загрузить аудитории: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private static func currentDayName(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        // 1 = Sun, 2 = Mon, 3 = Tue, 4 = Wed, 5 = Thu, 6 = Fri, 7 = Sat
        switch weekday {
        case 2: return "Понедельник"
        case 3: return "Вторник"
        case 4: return "Среда"
        case 5: return "Четверг"
        case 6: return "Пятница"
        case 7: return "Суббота"
        default: return "Понедельник"
        }
    }
}
