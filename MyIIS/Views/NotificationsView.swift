import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: PortalNotificationsViewModel

    var body: some View {
        content
            .navigationTitle(NSLocalizedString("notifications_title", comment: ""))
            .transparentInlineNavigationBar()
            .toolbar { toolbarContent }
            .task {
                await viewModel.loadInitial()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isInitialLoading {
            loadingView
        } else if viewModel.notifications.isEmpty {
            emptyState
        } else {
            notificationsList
        }
    }

    private var notificationsList: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                errorRow(message: errorMessage)
            }

            ForEach(viewModel.notifications) { notification in
                notificationButton(notification)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .task {
                        await viewModel.loadMoreIfNeeded(current: notification)
                    }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    PortalNotificationRow(notification: .placeholder)
                }
            }
            .padding(16)
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
        }
        .appBackground()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                viewModel.errorMessage == nil
                    ? NSLocalizedString("notifications_empty_title", comment: "")
                    : NSLocalizedString("notifications_error_title", comment: ""),
                systemImage: viewModel.errorMessage == nil ? "bell.slash" : "wifi.exclamationmark"
            )
        } description: {
            Text(
                viewModel.errorMessage
                    ?? NSLocalizedString("notifications_empty_message", comment: "")
            )
        } actions: {
            if viewModel.errorMessage != nil {
                Button(NSLocalizedString("notifications_retry", comment: "")) {
                    Task {
                        viewModel.clearError()
                        await viewModel.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .appBackground()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.hasUnread {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isMarkingRead {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(NSLocalizedString("notifications_marking_read", comment: ""))
                } else {
                    Button {
                        Task {
                            await viewModel.markAllAsRead()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel(NSLocalizedString("notifications_mark_all_read", comment: ""))
                }
            }
        }
    }

    @ViewBuilder
    private func notificationButton(_ notification: PortalNotification) -> some View {
        if notification.isViewed {
            PortalNotificationRow(notification: notification)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(notification.message)
                .accessibilityValue(
                    [
                        notification.displayDate,
                        NSLocalizedString("notifications_read", comment: "")
                    ].joined(separator: ", ")
                )
        } else {
            Button {
                Task {
                    await viewModel.markAsRead(notification)
                }
            } label: {
                PortalNotificationRow(notification: notification)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isMarkingRead)
            .accessibilityLabel(notification.message)
            .accessibilityValue(
                [
                    notification.displayDate,
                    NSLocalizedString("notifications_unread", comment: "")
                ].joined(separator: ", ")
            )
            .accessibilityHint(NSLocalizedString("notifications_mark_read_hint", comment: ""))
        }
    }

    private func errorRow(message: String) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        viewModel.clearError()
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(NSLocalizedString("notifications_retry", comment: ""))
            }
            .padding(14)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

struct NotificationsToolbarLabel: View {
    let unreadCount: Int

    var body: some View {
        Image(systemName: unreadCount > 0 ? "bell.fill" : "bell")
            .frame(width: 28, height: 28)
            .overlay(alignment: .topTrailing) {
                if unreadCount > 0 {
                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Capsule())
                        .offset(x: 7, y: -5)
                        .accessibilityHidden(true)
                }
            }
    }

    private var badgeText: String {
        unreadCount > 99 ? "99+" : String(unreadCount)
    }
}

private struct PortalNotificationRow: View {
    let notification: PortalNotification

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 13) {
                icon

                VStack(alignment: .leading, spacing: 8) {
                    Text(notification.message)
                        .font(.body.weight(notification.isViewed ? .regular : .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(notification.displayDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !notification.isViewed {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .opacity(notification.isViewed ? 0.82 : 1)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        Image(systemName: notification.type.systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(notification.type.tint)
            .frame(width: 38, height: 38)
            .background(notification.type.tint.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

private extension PortalNotificationKind {
    var systemImage: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

private extension PortalNotification {
    var displayDate: String {
        let components = date.split(separator: " ", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return date }

        let timeComponents = components[1].split(separator: ":")
        guard timeComponents.count >= 2 else { return date }

        return "\(components[0]) · \(timeComponents[0]):\(timeComponents[1])"
    }

    static let placeholder = PortalNotification(
        id: -1,
        message: "Уведомление личного кабинета загружается",
        isViewed: false,
        date: "13.07.2026 10:19:00",
        type: .info
    )
}

#if DEBUG
private final class PreviewPortalNotificationsService: PortalNotificationsServicing {
    func fetchUnreadCount() async throws -> Int {
        2
    }

    func fetchNotifications(page: Int, pageSize: Int) async throws -> PortalNotificationsPage {
        PortalNotificationsPage(
            notifications: [
                PortalNotification(
                    id: 3,
                    message: "Справка № 4449, заказанная Вами, распечатана.",
                    isViewed: false,
                    date: "06.07.2026 09:17:35",
                    type: .success
                ),
                PortalNotification(
                    id: 2,
                    message: "Ваши документы для общежития были приняты к рассмотрению.",
                    isViewed: false,
                    date: "11.06.2026 13:08:20",
                    type: .info
                ),
                PortalNotification(
                    id: 1,
                    message: "Заявка отклонена. Необходимо проверить указанные данные.",
                    isViewed: true,
                    date: "19.05.2026 12:45:38",
                    type: .failure
                )
            ],
            totalElements: 3,
            hasNext: false
        )
    }

    func markViewed(ids: [Int]) async throws {}
}

#Preview {
    NavigationStack {
        NotificationsView(
            viewModel: PortalNotificationsViewModel(
                service: PreviewPortalNotificationsService()
            )
        )
    }
}
#endif
