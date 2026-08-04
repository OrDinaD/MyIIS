import Combine
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
class LMSCourseDetailViewModel: ObservableObject {
    let courseId: Int
    @Published var detail: LMSCourseDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    init(courseId: Int) {
        self.courseId = courseId
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await LMSService.shared.fetchCourseDetail(id: courseId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct LMSCourseDetailView: View {
    let course: LMSCourse
    @StateObject private var viewModel: LMSCourseDetailViewModel
    @State private var presentedLink: LMSPresentedLink?
    @State private var presentedQuiz: LMSPresentedQuiz?
    @State private var presentedPage: LMSPresentedActivity?
    @State private var presentedFeedback: LMSPresentedActivity?
    @State private var previewFile: LMSPreviewFile?
    @State private var isPreparingResource = false
    @State private var resourceErrorMessage: String?

    init(course: LMSCourse) {
        self.course = course
        self._viewModel = StateObject(wrappedValue: LMSCourseDetailViewModel(courseId: course.id))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Загрузка курса...")
                        .foregroundColor(.secondary)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                    Text("Ошибка загрузки")
                        .font(.headline)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Повторить") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let detail = viewModel.detail {
                if detail.sections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Курс пуст")
                            .font(.headline)
                        Text("Не удалось найти элементы в этом курсе. Попробуйте обновить.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Обновить") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Course Header
                            VStack(alignment: .leading, spacing: 12) {
                                Text(detail.fullname)
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !course.teachers.isEmpty {
                                    HStack(alignment: .top) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .foregroundColor(.secondary)
                                        Text(course.teachersString)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)

                            // Modules
                            LazyVStack(spacing: 16) {
                                ForEach(detail.sections) { section in
                                    SectionView(section: section) { module in
                                        open(module)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Подготавливаем материалы курса...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.detail?.fullname ?? course.name)
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .task(id: course.id) {
            await viewModel.load()
        }
        .overlay {
            if isPreparingResource {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Открываем файл...")
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .sheet(item: $presentedLink) { link in
            LMSMaterialViewer(url: link.url)
        }
        .fullScreenCover(item: $presentedQuiz) { quiz in
            NavigationStack {
                LMSQuizView(quizURL: quiz.url)
            }
            .interactiveDismissDisabled(true)
        }
        .sheet(item: $presentedPage) { activity in
            NavigationStack {
                LMSPageContentView(url: activity.url, fallbackTitle: activity.title)
            }
        }
        .fullScreenCover(item: $presentedFeedback) { activity in
            NavigationStack {
                LMSFeedbackView(url: activity.url, fallbackTitle: activity.title)
            }
            .interactiveDismissDisabled(true)
        }
        .sheet(item: $previewFile) { file in
            NavigationStack {
                LMSQuickLookPreview(url: file.url)
                    .navigationTitle("Предпросмотр")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Закрыть") {
                                previewFile = nil
                            }
                        }
                    }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { resourceErrorMessage != nil },
            set: { if !$0 { resourceErrorMessage = nil } }
        )) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(resourceErrorMessage ?? "")
        }
    }

    private func open(_ module: LMSModule) {
        guard let url = module.url else {
            if let description = module.description, !description.isEmpty {
                resourceErrorMessage = description
            } else {
                resourceErrorMessage = String(localized: "Для этого элемента нет отдельной страницы или файла.")
            }
            return
        }

        if module.type == .quiz {
            presentedQuiz = LMSPresentedQuiz(url: url)
            return
        }

        if module.type == .page || url.path.contains("/mod/page/") {
            presentedPage = LMSPresentedActivity(url: url, title: module.name)
            return
        }

        if module.type == .feedback || module.type == .survey || module.type == .choice || url.path.contains("/mod/feedback/") {
            presentedFeedback = LMSPresentedActivity(url: url, title: module.name)
            return
        }

        if module.type == .resource {
            Task {
                await openResource(url)
            }
            return
        }

        if module.type == .url, let host = url.host, host != "lms.bsuir.by" {
            UIApplication.shared.open(url)
            return
        }

        presentedLink = LMSPresentedLink(url: url)
    }

    @MainActor
    private func openResource(_ url: URL) async {
        guard !isPreparingResource else { return }
        isPreparingResource = true
        defer { isPreparingResource = false }

        do {
            let fileURL = try await LMSResourceDownloader.download(url: url)
            previewFile = LMSPreviewFile(url: fileURL)
        } catch {
            resourceErrorMessage = error.localizedDescription
        }
    }
}

struct SectionView: View {
    let section: LMSSection
    let onOpenModule: (LMSModule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.name)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(section.modules.enumerated()), id: \.element.id) { index, module in
                    Button {
                        onOpenModule(module)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(module.type.color.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: module.type.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(module.type.color)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(module.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                HStack(spacing: 6) {
                                    Text(module.type.localizedName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let desc = module.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                        .padding(.top, 2)
                                }
                            }

                            Spacer()

                            if module.url != nil {
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < section.modules.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
    }
}

private struct LMSPresentedLink: Identifiable {
    let id = UUID()
    let url: URL
}

private struct LMSPresentedQuiz: Identifiable {
    let id = UUID()
    let url: URL
}

private struct LMSPresentedActivity: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

private struct LMSPreviewFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct LMSQuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private enum LMSResourceDownloader {
    static func download(url: URL) async throws -> URL {
        var request = URLRequest(url: normalized(url: url))
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        if let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://lms.bsuir.by")!) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 399).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let fileName = resolvedFileName(response: response, fallbackURL: request.url ?? url)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("LMS-")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(fileName)

        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    private static func normalized(url: URL) -> URL {
        guard url.host == "lms.bsuir.by",
              url.path == "/mod/resource/view.php",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return url
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "redirect" }) {
            queryItems.append(URLQueryItem(name: "redirect", value: "1"))
        }
        components.queryItems = queryItems
        return components.url ?? url
    }

    private static func resolvedFileName(response: URLResponse, fallbackURL: URL) -> String {
        if let suggested = response.suggestedFilename, !suggested.isEmpty {
            return suggested
        }

        var baseName = fallbackURL.lastPathComponent.isEmpty ? "material" : fallbackURL.lastPathComponent
        if let httpResponse = response as? HTTPURLResponse,
           let mimeType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.split(separator: ";").first,
           let ext = UTType(mimeType: String(mimeType))?.preferredFilenameExtension,
           !baseName.contains(".") {
            baseName += ".\(ext)"
        }

        return baseName
    }
}

private struct LMSMaterialViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LMSMaterialWebView(url: url)
                .navigationTitle("Материал")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct LMSMaterialWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        // Hide Moodle's web UI elements to make it feel like a native app page
        let cssString = """
        header, footer, nav, #page-header, .navbar, .block, #region-pre, #region-post, .activity-navigation { display: none !important; }
        #region-main {
            padding: 16px !important;
            width: 100% !important;
            margin: 0 !important;
            border: none !important;
            box-shadow: none !important;
            background: transparent !important;
        }
        body, #page, #page-content { background-color: transparent !important; padding: 0 !important; margin: 0 !important; }
        """
        let jsString = "var style = document.createElement('style'); style.innerHTML = '\(cssString)'; document.head.appendChild(style);"
        let script = WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        // Set background color to clear so SwiftUI background shows through
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.load(url: normalize(url), in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.load(url: normalize(url), in: uiView)
    }

    private func normalize(_ url: URL) -> URL {
        guard url.host == "lms.bsuir.by",
              url.path == "/mod/resource/view.php",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return url
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "redirect" }) {
            queryItems.append(URLQueryItem(name: "redirect", value: "1"))
        }
        components.queryItems = queryItems
        return components.url ?? url
    }

    final class Coordinator: NSObject {
        private var loadedURL: URL?

        func load(url: URL, in webView: WKWebView) {
            guard loadedURL != url else { return }
            loadedURL = url

            syncCookies(to: webView, targetURL: url) {
                var request = URLRequest(url: url)
                request.timeoutInterval = 60
                webView.load(request)
            }
        }

        private func syncCookies(to webView: WKWebView, targetURL: URL, completion: @escaping () -> Void) {
            guard targetURL.host == "lms.bsuir.by" else {
                completion()
                return
            }

            let store = webView.configuration.websiteDataStore.httpCookieStore
            let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://lms.bsuir.by")!) ?? []
            guard !cookies.isEmpty else {
                completion()
                return
            }

            let group = DispatchGroup()
            for cookie in cookies {
                group.enter()
                store.setCookie(cookie) {
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion()
            }
        }
    }
}

extension LMSModule.LMSModuleType {
    var color: Color {
        switch self {
        case .resource: return .blue
        case .assign: return .green
        case .quiz: return .orange
        case .forum: return .purple
        case .page: return .teal
        case .label: return .gray
        case .folder: return .indigo
        case .url: return .cyan
        case .feedback, .survey, .choice: return .pink
        case .unknown: return .secondary
        }
    }

    var localizedName: String {
        switch self {
        case .resource: return String(localized: "Файл")
        case .assign: return String(localized: "Задание")
        case .quiz: return String(localized: "Тест")
        case .forum: return String(localized: "Форум")
        case .page: return String(localized: "Страница")
        case .label: return String(localized: "Информация")
        case .folder: return String(localized: "Папка")
        case .url: return String(localized: "Ссылка")
        case .feedback, .survey: return String(localized: "Опрос")
        case .choice: return String(localized: "Выбор")
        case .unknown: return String(localized: "Элемент")
        }
    }
}
