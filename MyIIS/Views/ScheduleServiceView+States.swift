import SwiftUI

extension ScheduleServiceView {
    var emptySelectionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Text(NSLocalizedString("schedule_empty_cta_title", value: "Выберите расписание", comment: ""))
                .font(.title2.weight(.bold))

            Text(NSLocalizedString("schedule_empty_cta_subtitle", value: "Найдите группу или преподавателя, чтобы просматривать занятия и экзамены", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                isSearchSheetPresented = true
            } label: {
                Label(
                    NSLocalizedString("services_schedule_search_title", value: "Поиск расписания", comment: ""),
                    systemImage: "magnifyingglass"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    var scheduleLoadingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString(
                    "services_schedule_loading_selection",
                    value: "Загружаем выбранное расписание…",
                    comment: ""
                ))
                .font(.subheadline.weight(.semibold))

                Text(NSLocalizedString(
                    "services_schedule_loading_network_hint",
                    value: "При медленной сети это может занять немного времени.",
                    comment: ""
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    var scheduleInitialErrorView: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("services_schedule_empty_title", comment: ""),
                systemImage: "wifi.exclamationmark"
            )
        } description: {
            Text(viewModel.errorMessage ?? "")
        } actions: {
            Button(NSLocalizedString("common_retry", comment: "")) {
                viewModel.errorMessage = nil
                Task { await viewModel.refreshData() }
            }
            .buttonStyle(.borderedProminent)

            Button(NSLocalizedString("services_schedule_search_title", comment: "")) {
                viewModel.errorMessage = nil
                isSearchSheetPresented = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    var scheduleUnavailableView: some View {
        ContentUnavailableView {
            Label(
                viewModel.currentModeEmptyTitle,
                systemImage: viewModel.displayMode == .exams ? "graduationcap" : (viewModel.isSchedulePublicationPending ? "calendar.badge.clock" : "calendar")
            )
        } description: {
            Text(viewModel.currentModeEmptyText)
        } actions: {
            Button(NSLocalizedString("common_refresh", comment: "")) {
                Task { await viewModel.refreshData() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(.vertical, 24)
    }
}
