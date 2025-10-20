import SwiftUI

struct GroupView: View {
    @StateObject private var viewModel: GroupViewModel

    init(viewModel: GroupViewModel = GroupViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
            }
            .navigationTitle(viewModel.title)
            .toolbar { refreshButton }
        }
        .searchable(text: $viewModel.searchText, prompt: "Поиск по ФИО или контактам")
        .task { await viewModel.loadGroup() }
        .refreshable { await viewModel.refresh() }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.accentColor.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.members.isEmpty {
            ProgressView("Загружаем группу…")
                .progressViewStyle(.circular)
                .controlSize(.large)
        } else if let error = viewModel.errorMessage, viewModel.members.isEmpty {
            ErrorStateView(message: error) {
                Task { await viewModel.retry() }
            }
            .padding(.horizontal)
        } else if viewModel.hasResults {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if let error = viewModel.errorMessage {
                        InlineErrorView(message: error)
                    }

                    if let curator = viewModel.filteredCurator {
                        GroupSection(icon: "person.crop.circle.badge.questionmark", title: "Куратор") {
                            CuratorCard(curator: curator)
                        }
                    }

                    if let head = viewModel.headMember {
                        GroupSection(icon: "crown.fill", title: "Староста") {
                            GroupMemberCard(member: head)
                        }
                    }

                    if !viewModel.deputyMembers.isEmpty {
                        GroupSection(icon: "person.2.fill", title: "Актив группы") {
                            VStack(spacing: 16) {
                                ForEach(viewModel.deputyMembers) { member in
                                    GroupMemberCard(member: member)
                                }
                            }
                        }
                    }

                    if !viewModel.studentMembers.isEmpty {
                        GroupSection(icon: "person.3.fill", title: "Одногруппники") {
                            VStack(spacing: 16) {
                                ForEach(viewModel.studentMembers) { member in
                                    GroupMemberCard(member: member)
                                }
                            }
                        }
                    }

                    if viewModel.filteredMembers.isEmpty && viewModel.isSearchActive {
                        ContentUnavailableView(
                            "Нет совпадений",
                            systemImage: "magnifyingglass",
                            description: Text("Попробуйте изменить запрос")
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
        } else if viewModel.isSearchActive {
            ContentUnavailableView(
                "Нет совпадений",
                systemImage: "magnifyingglass",
                description: Text("Попробуйте изменить запрос")
            )
            .padding()
        } else {
            ContentUnavailableView(
                "Нет данных",
                systemImage: "person.3",
                description: Text("Не удалось загрузить список группы")
            )
            .padding()
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
        .accessibilityLabel("Обновить группу")
    }

    private var headerSection: some View {
        GroupSection(icon: "info.circle.fill", title: "Информация о группе") {
            VStack(alignment: .leading, spacing: 12) {
                if let subtitle = viewModel.subtitle {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if let memberCount = viewModel.memberCountText {
                    Label(memberCount, systemImage: "person.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Components

private struct GroupSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
                .shadow(.drop(radius: 12, y: 4))
        )
    }
}

private struct GroupMemberCard: View {
    let member: GroupMember

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                AvatarView(initials: member.initials)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(member.role.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !member.contacts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(member.contacts) { contact in
                        ContactRow(contact: contact)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08))
                )
        )
    }
}

private struct CuratorCard: View {
    let curator: GroupCurator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                AvatarView(initials: curator.initials)
                VStack(alignment: .leading, spacing: 4) {
                    Text(curator.fullName)
                        .font(.headline)
                    Text("Куратор группы")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !curator.contacts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(curator.contacts) { contact in
                        ContactRow(contact: contact)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08))
                )
        )
    }
}

private struct AvatarView: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.85),
                            Color.accentColor,
                            Color.accentColor.opacity(0.75)
                        ]),
                        center: .center
                    )
                )
                .frame(width: 56, height: 56)
                .shadow(radius: 12, y: 4)

            Text(initials.isEmpty ? "?" : initials)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }
}

private struct ContactRow: View {
    let contact: ContactItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: contact.iconName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(contact.formattedValue)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            if let url = contact.url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.forward")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Не удалось загрузить группу")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: retryAction) {
                Text("Повторить попытку")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

private struct InlineErrorView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

#if DEBUG
#Preview {
    GroupView(viewModel: .preview)
        .preferredColorScheme(.light)
}
#endif
