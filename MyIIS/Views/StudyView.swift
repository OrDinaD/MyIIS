import SwiftUI

@MainActor
struct StudyView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: StudyViewModel
    @State private var isShowingMarkSheetOrder = false
    @State private var isShowingCertificateOrder = false
    @State private var alertMessage: String?
    @State private var showsAlert = false

    init(viewModel: StudyViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init() {
        self.init(viewModel: StudyViewModel())
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Учеба")
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .sheet(isPresented: $isShowingMarkSheetOrder) {
            MarkSheetOrderSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingCertificateOrder) {
            CertificateOrderSheet(viewModel: viewModel)
        }
        .alert(alertMessage ?? "", isPresented: $showsAlert) {
            Button("ОК", role: .cancel) {}
        }
        .onChange(of: viewModel.toastMessage) { _, newValue in
            guard let message = newValue, !message.isEmpty else { return }
            alertMessage = message
            showsAlert = true
            viewModel.toastMessage = nil
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasLoadedContent {
            ProgressView("Загрузка учебных сервисов...")
                .controlSize(.large)
        } else if let message = viewModel.errorMessage, !viewModel.hasLoadedContent {
            StudyUnavailableView(message: message) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, 20)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isShowingStaleDataWarning {
                        StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                            await viewModel.refresh()
                        }
                    }
                    overviewCard
                    markSheetsCard
                    certificatesCard
                    lmsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay(alignment: .top) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 6)
                }
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Учебные сервисы")
                        .font(.title2.bold())
                    Text("Ведомостички, справки и заявки ДОТ в одном мобильном разделе.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: metricColumns, spacing: 10) {
                MetricTile(title: "Справки", value: "\(viewModel.dashboard.certificates.count)", tint: .green)
                MetricTile(title: "В обработке", value: "\(viewModel.processingCertificatesCount + viewModel.processingMarkSheetsCount)", tint: .orange)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var markSheetsCard: some View {
        StudySectionCard(
            title: "Ведомостички",
            subtitle: "Заказ платных ведомостей по дисциплине и преподавателю.",
            icon: "doc.text.magnifyingglass",
            tint: .blue,
            buttonTitle: "Заказать",
            action: { isShowingMarkSheetOrder = true },
            content: {
                if viewModel.dashboard.markSheets.isEmpty {
                    EmptyServiceState(text: "История ведомостичек пока пустая.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.dashboard.markSheets.prefix(3)) { request in
                            MarkSheetRequestRow(request: request) {
                                Task { await viewModel.cancelMarkSheet(request) }
                            }
                        }
                    }
                }
            }
        )
    }

    private var certificatesCard: some View {
        StudySectionCard(
            title: "Справки",
            subtitle: "Заказ справок с обычной или гербовой печатью.",
            icon: "checkmark.seal.fill",
            tint: .green,
            buttonTitle: "Заказать",
            action: { isShowingCertificateOrder = true },
            content: {
                if viewModel.dashboard.certificates.isEmpty {
                    EmptyServiceState(text: "История справок пока пустая.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.dashboard.certificates.prefix(4)) { request in
                            CertificateRequestRow(request: request) {
                                Task { await viewModel.cancelCertificate(request) }
                            }
                        }
                    }
                }
            }
        )
    }

    private var lmsCard: some View {
        StudySectionCard(
            title: "ДОТ",
            subtitle: "Заявки на изучение дисциплин с применением дистанционных технологий.",
            icon: "network",
            tint: .indigo,
            buttonTitle: nil,
            action: nil
        ) {
            if viewModel.dashboard.lmsApplications.isEmpty {
                EmptyServiceState(text: "Активных заявок ДОТ нет.")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.dashboard.lmsApplications) { application in
                        LMSApplicationRow(application: application)
                    }
                }
            }
        }
    }
}

private struct StudySectionCard<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let buttonTitle: String?
    let action: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        headerTitle
                        actionButton
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        headerTitle
                        Spacer(minLength: 8)
                        actionButton
                    }
                }
            }

            content
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var headerTitle: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let buttonTitle, let action {
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(dynamicTypeSize.isAccessibilitySize ? .regular : .small)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MarkSheetRequestRow: View {
    let request: MarkSheetRequest
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusDot(color: request.isProcessing ? .orange : .green)
                .padding(.top, 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(request.title)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    if let createdDate = request.createdDate {
                        Label(createdDate, systemImage: "calendar")
                    }
                    if let price = request.price {
                        Text(String(format: "%.2f BYN", price))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(request.status)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(request.isProcessing ? .orange : .secondary)
            }

            Spacer(minLength: 8)

            if request.isProcessing {
                Button("Отменить", role: .destructive, action: onCancel)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CertificateRequestRow: View {
    let request: CertificateRequest
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusDot(color: statusColor)
                .padding(.top, 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("№" + String(request.number))
                        .font(.subheadline.weight(.semibold))
                    Text(request.certificateType)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
                Text(request.provisionPlace)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label(request.dateOrder, systemImage: "calendar")
                    Text(request.statusText)
                        .foregroundStyle(statusColor)
                }
                .font(.caption)
                if let reason = request.rejectionReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            if request.isProcessing {
                Button("Отменить", role: .destructive, action: onCancel)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusColor: Color {
        switch request.status {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .secondary
        }
    }
}

private struct LMSApplicationRow: View {
    let application: LMSApplication

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(color: .indigo)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(application.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = application.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let status = application.status {
                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.indigo)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(color.opacity(0.22), lineWidth: 6))
    }
}

private struct EmptyServiceState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StudyUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#if DEBUG
#Preview {
    StudyView(viewModel: .preview)
}
#endif
