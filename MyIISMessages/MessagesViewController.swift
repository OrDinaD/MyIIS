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
            ZStack {
                Color(uiColor: .systemBackground)
                LinearGradient(
                    colors: [
                        Color(red: 0.00, green: 0.44, blue: 0.39).opacity(0.22),
                        Color(red: 0.25, green: 0.30, blue: 0.63).opacity(0.16),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            brandGlyph

            VStack(alignment: .leading, spacing: 2) {
                Text("MyIIS")
                    .font(.title3.weight(.semibold))
                Text("PNG-карточки зачетки без ссылок")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Обновить данные")
        }
    }

    private var brandGlyph: some View {
        Image(systemName: "graduationcap.fill")
            .font(.system(size: 23, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.00, green: 0.54, blue: 0.48), Color(red: 0.00, green: 0.36, blue: 0.54)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func content(for snapshot: MessageGradebookSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryGrid(snapshot)

            if !isExpanded {
                Button(action: onExpand) {
                    Label("Все семестры и предметы", systemImage: "rectangle.expand.vertical")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(displayedSections(from: snapshot)) { section in
                sectionView(section)
            }

            footer(snapshot.updatedAt)
        }
    }

    private func summaryGrid(_ snapshot: MessageGradebookSnapshot) -> some View {
        let items = MessageShareItem.summaryItems(from: snapshot)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { item in
                shareTile(item, style: .hero)
            }
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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.semester.title)
                        .font(.headline.weight(.semibold))
                    Text("PNG с предметами и оценками")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(section.semester.averageText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(red: 0.00, green: 0.44, blue: 0.39))
                    .monospacedDigit()
            }

            shareTile(MessageShareItem(semester: section.semester), style: .row)

            ForEach(section.subjects) { subject in
                shareTile(MessageShareItem(subject: subject, semester: section.semester), style: .row)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shareTile(_ item: MessageShareItem, style: ShareTileStyle) -> some View {
        Button {
            onShare(item)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.system(size: style.iconSize, weight: .bold))
                    .foregroundStyle(item.accent)
                    .frame(width: style.iconFrame, height: style.iconFrame)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: style.iconCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(style.titleFont)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("PNG")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(item.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .glassEffect(.regular, in: Capsule())
                    }

                    Text(item.subtitle)
                        .font(style.subtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(style.subtitleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                if sendingItemID == item.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(style.padding)
            .frame(maxWidth: .infinity, minHeight: style.minHeight, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(sendingItemID != nil)
        .accessibilityLabel("Вставить PNG: \(item.title)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(red: 0.00, green: 0.44, blue: 0.39))
            Text("Зачетка пока недоступна")
                .font(.headline.weight(.semibold))
            Text("Откройте зачетку в MyIIS один раз. После этого здесь появятся PNG-карточки для iMessage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func footer(_ date: Date) -> some View {
        Text("Данные: \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

private enum ShareTileStyle {
    case hero
    case row

    var iconSize: CGFloat { self == .hero ? 22 : 19 }
    var iconFrame: CGFloat { self == .hero ? 48 : 42 }
    var iconCornerRadius: CGFloat { self == .hero ? 14 : 12 }
    var cornerRadius: CGFloat { self == .hero ? 22 : 18 }
    var minHeight: CGFloat { self == .hero ? 92 : 70 }
    var padding: CGFloat { self == .hero ? 14 : 12 }
    var subtitleLineLimit: Int { self == .hero ? 3 : 2 }

    var titleFont: Font {
        self == .hero ? .headline.weight(.semibold) : .subheadline.weight(.semibold)
    }

    var subtitleFont: Font {
        self == .hero ? .subheadline : .caption
    }
}
