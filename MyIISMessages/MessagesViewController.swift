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
        controller.view.backgroundColor = .systemGroupedBackground
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
                self?.insertMessage(for: item)
            }
        )
    }

    private func insertMessage(for item: MessageShareItem) {
        guard let conversation = activeConversation, let snapshot else { return }

        sendingItemID = item.id
        sendErrorMessage = nil
        updateRootView()

        let message = MSMessage()
        message.url = item.messageURL
        message.summaryText = item.summaryText

        let layout = MSMessageTemplateLayout()
        layout.caption = item.title
        layout.subcaption = item.subtitle
        layout.trailingCaption = item.trailingCaption
        layout.trailingSubcaption = item.trailingSubcaption
        layout.image = MessageCardImageRenderer.image(for: item, snapshot: snapshot)
        message.layout = layout

        conversation.insert(message) { [weak self] error in
            Task { @MainActor in
                self?.sendingItemID = nil
                self?.sendErrorMessage = error?.localizedDescription
                self?.updateRootView()
            }
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
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color(red: 0.00, green: 0.44, blue: 0.39), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("MyIIS")
                    .font(.headline.weight(.semibold))
                Text("Отправьте зачетку в чат")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Обновить данные")
        }
    }

    @ViewBuilder
    private func content(for snapshot: MessageGradebookSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryGrid(snapshot)

            if !isExpanded {
                Button(action: onExpand) {
                    Label("Показать все семестры", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            ForEach(displayedSections(from: snapshot)) { section in
                sectionView(section)
            }

            footer(snapshot.updatedAt)
        }
    }

    private func summaryGrid(_ snapshot: MessageGradebookSnapshot) -> some View {
        let items = MessageShareItem.summaryItems(from: snapshot)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items) { item in
                shareTile(item)
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
        return [MessageGradebookSection(semester: latestSemester, subjects: Array(latestSemester.subjects.prefix(4)))]
    }

    private func sectionView(_ section: MessageGradebookSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.semester.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Средний: \(section.semester.averageText)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            shareTile(MessageShareItem(semester: section.semester))

            ForEach(section.subjects) { subject in
                shareTile(MessageShareItem(subject: subject, semester: section.semester))
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1)
        }
    }

    private func shareTile(_ item: MessageShareItem) -> some View {
        Button {
            onShare(item)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(item.accent)
                    .frame(width: 32, height: 32)
                    .background(item.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                if sendingItemID == item.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(sendingItemID != nil)
        .accessibilityLabel("Поделиться: \(item.title)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(red: 0.00, green: 0.44, blue: 0.39))
            Text("Зачетка пока недоступна")
                .font(.headline.weight(.semibold))
            Text("Откройте зачетку в MyIIS один раз, чтобы приложение сохранило данные для быстрого шаринга в iMessage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func footer(_ date: Date) -> some View {
        Text("Обновлено: \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

private struct MessageGradebookSection: Identifiable {
    let semester: MessageGradebookSnapshot.Semester
    let subjects: [MessageGradebookSnapshot.Subject]

    var id: String {
        semester.id
    }
}

private struct MessageShareItem: Identifiable {
    enum Kind {
        case overall
        case semester(String)
        case subject(String, String)
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let trailingCaption: String
    let trailingSubcaption: String
    let summaryText: String
    let symbolName: String
    let accent: Color

    var messageURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "myiis.local"
        components.path = "/gradebook/share"
        components.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "title", value: title)
        ]
        return components.url
    }

    init(overall snapshot: MessageGradebookSnapshot) {
        id = "overall"
        kind = .overall
        title = "Зачетка MyIIS"
        subtitle = "Номер: \(snapshot.number)"
        trailingCaption = snapshot.overallAverageText
        trailingSubcaption = "общий средний"
        summaryText = "MyIIS: общий средний балл \(snapshot.overallAverageText)"
        symbolName = "graduationcap.fill"
        accent = Color(red: 0.00, green: 0.44, blue: 0.39)
    }

    init(semester: MessageGradebookSnapshot.Semester) {
        id = "semester-\(semester.id)"
        kind = .semester(semester.id)
        title = semester.title
        subtitle = "Предметов: \(semester.subjects.count)"
        trailingCaption = semester.averageText
        trailingSubcaption = "средний"
        summaryText = "MyIIS: \(semester.title), средний балл \(semester.averageText)"
        symbolName = "books.vertical.fill"
        accent = Color(red: 0.25, green: 0.30, blue: 0.63)
    }

    init(subject: MessageGradebookSnapshot.Subject, semester: MessageGradebookSnapshot.Semester) {
        id = "subject-\(semester.id)-\(subject.id)"
        kind = .subject(semester.id, subject.id)
        title = subject.abbreviation
        subtitle = subject.fullName
        trailingCaption = subject.grade
        trailingSubcaption = subject.controlForm
        summaryText = "MyIIS: \(subject.fullName) — \(subject.grade)"
        symbolName = "checkmark.seal.fill"
        accent = Color(red: 0.72, green: 0.41, blue: 0.09)
    }

    static func summaryItems(from snapshot: MessageGradebookSnapshot) -> [MessageShareItem] {
        var items = [MessageShareItem(overall: snapshot)]
        if let latestSemester = snapshot.latestSemester {
            items.append(MessageShareItem(semester: latestSemester))
        }
        return items
    }
}

private enum MessageCardImageRenderer {
    static func image(for item: MessageShareItem, snapshot: MessageGradebookSnapshot) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360), format: format)

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: 640, height: 360)
            UIColor.systemBackground.setFill()
            context.fill(rect)

            let accent = UIColor(item.accent)
            let accentPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 18, height: 360), cornerRadius: 0)
            accent.setFill()
            accentPath.fill()

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 38, weight: .bold)
            let symbol = UIImage(systemName: item.symbolName, withConfiguration: symbolConfig)?.withTintColor(accent, renderingMode: .alwaysOriginal)
            symbol?.draw(in: CGRect(x: 44, y: 38, width: 46, height: 46))

            draw("MyIIS", in: CGRect(x: 108, y: 34, width: 460, height: 28), font: .systemFont(ofSize: 22, weight: .semibold), color: .secondaryLabel)
            draw(item.title, in: CGRect(x: 44, y: 104, width: 410, height: 56), font: .systemFont(ofSize: 42, weight: .heavy), color: .label)
            draw(item.subtitle, in: CGRect(x: 46, y: 170, width: 410, height: 76), font: .systemFont(ofSize: 24, weight: .medium), color: .secondaryLabel)
            draw(item.trailingCaption, in: CGRect(x: 472, y: 92, width: 124, height: 64), font: .monospacedDigitSystemFont(ofSize: 46, weight: .bold), color: accent)
            draw(
                item.trailingSubcaption,
                in: CGRect(x: 472, y: 154, width: 124, height: 34),
                font: .systemFont(ofSize: 19, weight: .semibold),
                color: .secondaryLabel
            )

            let footer = "Зачетка \(snapshot.number) · \(snapshot.updatedAt.formatted(date: .numeric, time: .shortened))"
            draw(footer, in: CGRect(x: 46, y: 288, width: 548, height: 30), font: .systemFont(ofSize: 20, weight: .medium), color: .tertiaryLabel)
        }
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
    }
}

private struct MessageGradebookSnapshot: Codable, Equatable {
    let number: String
    let overallAverageText: String
    let updatedAt: Date
    let semesters: [Semester]

    var latestSemester: Semester? {
        semesters.last
    }

    struct Semester: Codable, Equatable, Identifiable {
        let id: String
        let averageText: String
        let subjects: [Subject]

        var title: String {
            "Семестр \(id)"
        }
    }

    struct Subject: Codable, Equatable, Identifiable {
        let id: String
        let abbreviation: String
        let fullName: String
        let controlForm: String
        let grade: String
        let averageText: String
        let retakesText: String
        let dateText: String
        let teacherText: String
    }
}

private enum MessageGradebookDataStore {
    private enum Key {
        static let snapshot = "myiis_gradebook_message_snapshot_v1"
    }

    private static let appGroupIdentifier = "group.com.OrDinaD.MyIIS"

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    static func loadSnapshot() -> MessageGradebookSnapshot? {
        guard let defaults, let data = MessagePayloadStore.load(forKey: Key.snapshot, from: defaults) else {
            return nil
        }
        return try? JSONDecoder().decode(MessageGradebookSnapshot.self, from: data)
    }
}

private enum MessagePayloadStore {
    private static let maxPayloadBytes = 3_500_000

    static func load(forKey key: String, from defaults: UserDefaults) -> Data? {
        guard let data = defaults.data(forKey: key), data.count < maxPayloadBytes else {
            return nil
        }
        return data
    }
}
