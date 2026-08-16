//
//  ScheduleSettingsView.swift
//  MyIIS
//
import SwiftUI

struct ScheduleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ScheduleDisplayPreferences.showsMidPairBreaksKey, store: ScheduleDisplayPreferences.defaults)
    private var showsMidPairBreaks = false

    @AppStorage(ScheduleDisplayPreferences.hidePastLessonsKey, store: ScheduleDisplayPreferences.defaults)
    private var hidePastLessons = false

    @AppStorage(ScheduleDisplayPreferences.cardDensityKey, store: ScheduleDisplayPreferences.defaults)
    private var cardDensityRaw = ScheduleCardDensity.regular.rawValue

    @AppStorage(ScheduleDisplayPreferences.otherSubgroupDisplayKey, store: ScheduleDisplayPreferences.defaults)
    private var otherSubgroupRaw = ScheduleOtherSubgroupDisplay.compact.rawValue

    @AppStorage("initial_startup_tab")
    private var initialStartupTab = "schedule"

    @State private var selectedIcon = AppIconManager.currentIcon
    @State private var iconAlertMessage: String?

    // Color states
    @State private var lectureColor: Color = ScheduleColorPreferences.color(for: .lecture)
    @State private var practiceColor: Color = ScheduleColorPreferences.color(for: .practice)
    @State private var labColor: Color = ScheduleColorPreferences.color(for: .laboratory)
    @State private var consultationColor: Color = ScheduleColorPreferences.color(for: .consultation)
    @State private var examColor: Color = ScheduleColorPreferences.color(for: .exam)
    @State private var otherColor: Color = ScheduleColorPreferences.color(for: .other)

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                subgroupSection
                colorsSection
                if AppIconManager.supportsAlternateIcons {
                    appIconSection
                }
                startupSection
                resetSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(NSLocalizedString("schedule_settings_title", value: "Настройки расписания", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common_done", value: "Готово", comment: "")) {
                        dismiss()
                    }
                }
            }
            .alert(
                NSLocalizedString("common_error", comment: ""),
                isPresented: Binding(get: { iconAlertMessage != nil }, set: { if !$0 { iconAlertMessage = nil } }),
                actions: { Button(NSLocalizedString("common_ok", comment: "")) {} },
                message: { Text(iconAlertMessage ?? "") }
            )
        }
    }

    private var displaySection: some View {
        Section(NSLocalizedString("schedule_settings_display_header", value: "Отображение", comment: "")) {
            Toggle(isOn: $showsMidPairBreaks) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("settings_schedule_breaks_title", comment: ""))
                            .fontWeight(.medium)
                        Text(NSLocalizedString("settings_schedule_breaks_subtitle", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(.purple)
                }
            }
            .onChange(of: showsMidPairBreaks) {
                ScheduleDisplayPreferences.reloadClassScheduleWidget()
            }

            Toggle(isOn: $hidePastLessons) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("schedule_hide_past_title", value: "Скрывать прошедшие занятия", comment: ""))
                            .fontWeight(.medium)
                        Text(NSLocalizedString("schedule_hide_past_subtitle", value: "Сворачивать завершённые пары в течение дня", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .foregroundStyle(.blue)
                }
            }

            Picker(
                NSLocalizedString("schedule_density_title", value: "Плотность карточек", comment: ""),
                selection: $cardDensityRaw
            ) {
                ForEach(ScheduleCardDensity.allCases) { density in
                    Text(density.localizedTitle).tag(density.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var subgroupSection: some View {
        Section(NSLocalizedString("schedule_settings_subgroup_header", value: "Подгруппы", comment: "")) {
            Picker(
                NSLocalizedString("schedule_other_subgroup_title", value: "Другая подгруппа", comment: ""),
                selection: $otherSubgroupRaw
            ) {
                ForEach(ScheduleOtherSubgroupDisplay.allCases) { option in
                    Text(option.localizedTitle).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var colorsSection: some View {
        Section {
            colorRow(category: .lecture, color: $lectureColor)
            colorRow(category: .practice, color: $practiceColor)
            colorRow(category: .laboratory, color: $labColor)
            colorRow(category: .consultation, color: $consultationColor)
            colorRow(category: .exam, color: $examColor)
            colorRow(category: .other, color: $otherColor)

            Button(NSLocalizedString("schedule_colors_reset", value: "Сбросить цвета по умолчанию", comment: "")) {
                resetAllColors()
            }
            .font(.subheadline)
            .foregroundStyle(.red)
        } header: {
            Text(NSLocalizedString("schedule_colors_header", value: "Цвета типов занятий", comment: ""))
        } footer: {
            Text(NSLocalizedString("schedule_colors_footer", value: "Выбранные цвета применяются в расписании и виджетах.", comment: ""))
                .font(.caption)
        }
    }

    private func colorRow(category: LessonTypeCategory, color: Binding<Color>) -> some View {
        HStack {
            Image(systemName: category.defaultSymbolName)
                .foregroundStyle(color.wrappedValue)
                .frame(width: 24)

            Text(category.localizedTitle)
                .font(.body)

            Spacer()

            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color.wrappedValue) { _, newColor in
                    if let hex = newColor.toHex() {
                        ScheduleColorPreferences.setHexColor(hex, for: category)
                    }
                }
        }
    }

    private func resetAllColors() {
        ScheduleColorPreferences.resetAllColors()
        lectureColor = ScheduleColorPreferences.color(for: .lecture)
        practiceColor = ScheduleColorPreferences.color(for: .practice)
        labColor = ScheduleColorPreferences.color(for: .laboratory)
        consultationColor = ScheduleColorPreferences.color(for: .consultation)
        examColor = ScheduleColorPreferences.color(for: .exam)
        otherColor = ScheduleColorPreferences.color(for: .other)
    }

    private var appIconSection: some View {
        Section(NSLocalizedString("about_section_app_icon", comment: "Иконка приложения")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppIconOption.allCases) { option in
                        Button {
                            Task { await applyIcon(option) }
                        } label: {
                            VStack(spacing: 6) {
                                Image(option.previewAssetName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(option == selectedIcon ? Color.green : Color.white.opacity(0.2), lineWidth: option == selectedIcon ? 2 : 1)
                                    )

                                Text(option.displayName)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)

                                Image(systemName: option == selectedIcon ? "checkmark.circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundStyle(option == selectedIcon ? Color.green : Color.secondary.opacity(0.4))
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                        .disabled(option == selectedIcon)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func applyIcon(_ option: AppIconOption) async {
        guard option != selectedIcon else { return }
        do {
            try await AppIconManager.setIcon(option)
            selectedIcon = option
        } catch {
            iconAlertMessage = NSLocalizedString("about_app_icon_error_message", comment: "")
        }
    }

    private var startupSection: some View {
        Section(NSLocalizedString("schedule_startup_header", value: "Запуск приложения", comment: "")) {
            Picker(
                NSLocalizedString("schedule_startup_tab_title", value: "Открывать при запуске", comment: ""),
                selection: $initialStartupTab
            ) {
                Text(NSLocalizedString("tab_schedule", comment: "")).tag("schedule")
                Text(NSLocalizedString("tab_attendance", comment: "")).tag("attendance")
                Text(NSLocalizedString("tab_rating", comment: "")).tag("rating")
                Text(NSLocalizedString("tab_profile", comment: "")).tag("profile")
                Text(NSLocalizedString("tab_services", comment: "")).tag("services")
            }
            .pickerStyle(.menu)
        }
    }

    private var resetSection: some View {
        Section {
            Button(NSLocalizedString("schedule_settings_reset_all", value: "Сбросить все настройки расписания", comment: "")) {
                resetAllSettings()
            }
            .foregroundStyle(.red)
        }
    }

    private func resetAllSettings() {
        showsMidPairBreaks = false
        hidePastLessons = false
        cardDensityRaw = ScheduleCardDensity.regular.rawValue
        otherSubgroupRaw = ScheduleOtherSubgroupDisplay.compact.rawValue
        initialStartupTab = "schedule"
        resetAllColors()
    }
}

#Preview {
    ScheduleSettingsView()
}
