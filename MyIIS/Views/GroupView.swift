import SwiftUI
import UIKit

struct GroupView: View {
    @StateObject private var viewModel = GroupViewModel()
    @Environment(\.openURL) var openURL
    @State private var sharePayload: SharePayload?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isShowingStaleDataWarning {
                    StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                        Task { await viewModel.reload() }
                    }
                    .padding(.horizontal, 16)
                }

                summaryCard
                    .padding(.horizontal, 16)

                studentsCard
                    .padding(.horizontal, 16)

                if let curator = viewModel.groupInfo?.studentGroupCuratorDto {
                    curatorCard(curator)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.bottom, 28)
        }
        .glassScrollPadding(top: 20)
        .background(
            LinearGradient(
                colors: Color.gradientBackground,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Группа")
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.downloadGroupReport() }
                } label: {
                    if viewModel.isDownloadingReport {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .accessibilityLabel("Скачать список группы")
            }
        }
        .refreshable {
            await viewModel.reload()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.downloadedReportURL) { _, newValue in
            guard let newValue else { return }
            if FileManager.default.fileExists(atPath: newValue.path) {
                sharePayload = SharePayload(url: newValue)
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: [payload.url])
        }
    }

    private var summaryCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Группа \(viewModel.groupTitle)", systemImage: "person.3.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                metricTile(
                    title: "Студентов",
                    value: "\(viewModel.studentsCount)",
                    icon: "person.2"
                )
            }
        }
    }

    private func curatorCard(_ curator: GroupCurator) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label("Куратор", systemImage: "person.crop.square.filled.and.at.rectangle")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(curator.fio)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                if let position = optionalText(curator.position) {
                    Text(position)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let phone = optionalText(curator.phone) {
                    contactRow(icon: "phone.fill", text: phone)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = phone
                            } label: {
                                Label("Скопировать номер", systemImage: "doc.on.doc")
                            }
                            Button {
                                openPhone(phone)
                            } label: {
                                Label("Открыть в Телефоне", systemImage: "phone")
                            }
                        }
                        .onTapGesture {
                            openPhone(phone)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Телефон куратора")
                        .accessibilityValue(phone)
                        .accessibilityHint("Открывает номер в Телефоне")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            openPhone(phone)
                        }
                }

                if let email = optionalText(curator.email) {
                    contactRow(icon: "envelope.fill", text: email)
                }
            }
        }
    }

    private var studentsCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Состав группы", systemImage: "list.bullet")
                        .font(.headline)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let error = viewModel.errorMessage, viewModel.groupInfo == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Не удалось загрузить группу", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Повторить") {
                            Task { await viewModel.reload() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding(.vertical, 6)
                } else if viewModel.students.isEmpty {
                    Text(viewModel.isLoading ? "Загрузка списка..." : "Студенты не найдены")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.students.enumerated()), id: \.offset) { index, student in
                            studentRow(index: index + 1, student: student)
                        }
                    }
                }
            }
        }
    }

    private func studentRow(index: Int, student: GroupStudent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(student.fio)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if viewModel.isCurrentUser(student) {
                        roleBadge(text: "Я", tint: .blue)
                    }

                    if student.isHeadman {
                        roleBadge(text: "Староста", tint: .orange)
                    }
                }

                if let position = optionalText(student.position), !student.isHeadman {
                    Text(position)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.2)
        }
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.85))
        )
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

}

private struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        GroupView()
    }
}
