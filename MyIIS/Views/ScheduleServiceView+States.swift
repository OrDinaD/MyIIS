import SwiftUI

extension ScheduleServiceView {
    var scheduleSkeletonView: some View {
        ScheduleSkeletonView(density: cardDensity)
    }

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

struct ScheduleSkeletonView: View {
    var density: ScheduleCardDensity = .regular
    @ScaledMetric(relativeTo: .title3) private var headingHeight = 24
    @ScaledMetric(relativeTo: .headline) private var titleHeight = 14

    private var isCompact: Bool { density == .compact }
    private var avatarSize: CGFloat { isCompact ? 48 : 56 }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(0..<2) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 210, height: headingHeight)

                    ForEach(0..<3) { _ in
                        lessonPlaceholder
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("common_loading", comment: ""))
        .allowsHitTesting(false)
    }

    private var lessonPlaceholder: some View {
        HStack(spacing: isCompact ? 10 : 12) {
            VStack(alignment: .trailing, spacing: 5) {
                bar(width: 42, height: titleHeight)
                bar(width: 32, height: 10)
            }
            .frame(width: isCompact ? 58 : 62, alignment: .trailing)

            RoundedRectangle(cornerRadius: 3.5)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: isCompact ? 7 : 9, height: avatarSize)

            VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(maxWidth: 150)
                    .frame(height: titleHeight)
                bar(width: 60, height: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Circle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: avatarSize, height: avatarSize)
        }
        .padding(.horizontal, isCompact ? 12 : 14)
        .padding(.vertical, isCompact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: isCompact ? 14 : 16)
        )
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.18))
            .frame(width: width, height: height)
    }
}

#Preview("Standard loading") {
    NavigationStack {
        ScrollView {
            ScheduleSkeletonView(density: .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("420603")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Compact loading") {
    NavigationStack {
        ScrollView {
            ScheduleSkeletonView(density: .compact)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("420603")
        .navigationBarTitleDisplayMode(.inline)
    }
}
