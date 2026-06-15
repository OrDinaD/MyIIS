import Messages
import SwiftUI
import UIKit

final class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<MessagesRootView>?
    private var snapshot: MessageGradebookSnapshot?
    private var sendErrorMessage: String?
    private var sendingItemID: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        snapshot = MessageGradebookDataStore.loadSnapshot()
        installRootView()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        snapshot = MessageGradebookDataStore.loadSnapshot()
        updateRootView()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        updateRootView()
    }

    private func installRootView() {
        let controller = UIHostingController(rootView: makeRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear
        addChild(controller)
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func updateRootView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> MessagesRootView {
        MessagesRootView(
            snapshot: snapshot,
            presentationStyle: presentationStyle,
            sendingItemID: sendingItemID,
            errorMessage: sendErrorMessage,
            onRefresh: { [weak self] in
                self?.snapshot = MessageGradebookDataStore.loadSnapshot()
                self?.sendErrorMessage = nil
                self?.updateRootView()
            },
            onExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            },
            onShare: { [weak self] item in
                self?.insertImageAttachment(for: item)
            }
        )
    }

    private func insertImageAttachment(for item: MessageShareItem) {
        guard let conversation = activeConversation, let snapshot else { return }

        sendingItemID = item.id
        sendErrorMessage = nil
        updateRootView()

        do {
            let imageURL = try MessageShareImageRenderer.renderPNG(for: item, snapshot: snapshot)
            conversation.insertAttachment(imageURL, withAlternateFilename: item.fileName) { [weak self] error in
                let errorMessage = error?.localizedDescription
                DispatchQueue.main.async { [weak self, errorMessage] in
                    self?.sendingItemID = nil
                    self?.sendErrorMessage = errorMessage
                    self?.updateRootView()

                    if errorMessage == nil {
                        self?.requestPresentationStyle(.compact)
                    }
                }
            }
        } catch {
            sendingItemID = nil
            sendErrorMessage = error.localizedDescription
            updateRootView()
        }
    }
}

private struct MessagesRootView: View {
    let snapshot: MessageGradebookSnapshot?
    let presentationStyle: MSMessagesAppPresentationStyle
    let sendingItemID: String?
    let errorMessage: String?
    let onRefresh: () -> Void
    let onExpand: () -> Void
    let onShare: (MessageShareItem) -> Void

    private var isExpanded: Bool {
        presentationStyle == .expanded
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let errorMessage {
                    inlineError(errorMessage)
                }

                if let snapshot {
                    content(for: snapshot)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("GradebookShareAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("MyIIS")
                    .font(.title3.weight(.semibold))
            }

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Обновить данные")
        }
    }

    @ViewBuilder
    private func content(for snapshot: MessageGradebookSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isExpanded {
                Button(action: onExpand) {
                    Label("Все семестры и предметы", systemImage: "rectangle.expand.vertical")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(displayedSections(from: snapshot)) { section in
                sectionView(section)
            }

            footer(snapshot.updatedAt)
        }
    }

    private func displayedSections(from snapshot: MessageGradebookSnapshot) -> [MessageGradebookSection] {
        if isExpanded {
            return snapshot.semesters.reversed().map { semester in
                MessageGradebookSection(semester: semester, subjects: semester.subjects)
            }
        }

        guard let latestSemester = snapshot.latestSemester else { return [] }
        return [MessageGradebookSection(semester: latestSemester, subjects: Array(latestSemester.subjects.prefix(5)))]
    }

    private func sectionView(_ section: MessageGradebookSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onShare(MessageShareItem(semester: section.semester))
            } label: {
                HStack(alignment: .center) {
                    Spacer()
                    Text(section.semester.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.63))
                    if sendingItemID == "semester-\(section.semester.id)" {
                        ProgressView().controlSize(.small).padding(.leading, 6)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.63))
                            .padding(.leading, 6)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(sendingItemID != nil)

            ForEach(section.subjects) { subject in
                subjectTile(MessageShareItem(subject: subject, semester: section.semester))
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func subjectTile(_ item: MessageShareItem) -> some View {
        Button {
            onShare(item)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(item.accent)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 6)

                if sendingItemID == item.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(item.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(sendingItemID != nil)
        .accessibilityLabel("Вставить \(item.title)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(red: 0.00, green: 0.44, blue: 0.39))
            Text("Зачетка пока недоступна")
                .font(.headline.weight(.semibold))
            Text("Откройте зачетку в MyIIS один раз. После этого здесь появятся карточки для iMessage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func footer(_ date: Date) -> some View {
        Text("Данные: \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

