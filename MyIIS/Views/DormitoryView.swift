import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct DormitoryView: View {

    @StateObject private var viewModel: DormitoryViewModel

    init(viewModel: DormitoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: DormitoryViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if let error = viewModel.errorMessage {
                            ErrorCard(message: error) {
                                Task { await viewModel.reload() }
                            }
                        }

                        if viewModel.isLoading && viewModel.dormitoryInfo == nil {
                            ProgressView("Загрузка данных…")
                                .tint(.purple)
                                .frame(maxWidth: .infinity)
                        }

                        if let info = viewModel.dormitoryInfo {
                            DormitorySummaryCard(info: info)
                            PaymentStatusCard(info: info) {
                                if let paymentAction = viewModel.actions.first(where: { $0.type == .makePayment }) {
                                    viewModel.triggerAction(paymentAction)
                                } else {
                                    viewModel.triggerAction(DormitoryAction(type: .makePayment))
                                }
                            }
                        }

                        if !viewModel.history.isEmpty {
                            HistorySection(history: viewModel.history)
                        } else if !viewModel.isLoading && viewModel.errorMessage == nil {
                            DormitoryGlassCard {
                                VStack(spacing: 12) {
                                    Image(systemName: "clock.badge.questionmark")
                                        .font(.largeTitle)
                                        .foregroundStyle(.tertiary)

                                    Text("У вас пока нет истории движений по общежитию.")
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        if !viewModel.actions.isEmpty {
                            ActionsSection(actions: viewModel.actions) { action in
                                viewModel.triggerAction(action)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Общежитие")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadIfNeeded() }
            .refreshable { await viewModel.reload() }
            .alert("Действие", isPresented: infoAlertBinding) {
                Button("Понятно", role: .cancel) {
                    viewModel.dismissInfoMessage()
                }
            } message: {
                if let message = viewModel.infoMessage {
                    Text(message)
                }
            }
        }
    }

    private var infoAlertBinding: Binding<Bool> {
        Binding(get: { viewModel.infoMessage != nil }, set: { newValue in
            if !newValue { viewModel.dismissInfoMessage() }
        })
    }
}

private struct BackgroundView: View {
    var body: some View {
        LinearGradient(colors: [
            Color(.displayP3, red: 0.10, green: 0.08, blue: 0.20, opacity: 1.0),
            Color(.displayP3, red: 0.05, green: 0.07, blue: 0.14, opacity: 1.0)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay(
            RadialGradient(colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.02)
            ], center: .topLeading, startRadius: 40, endRadius: 420)
        )
    }
}

private struct DormitoryGlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(LinearGradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.15)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 18, x: 0, y: 14)
            )
    }
}

private struct DormitorySummaryCard: View {
    let info: DormitoryInfo

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    var body: some View {
        DormitoryGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: info.status.systemImageName)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.purple, .white)
                        .font(.system(size: 34))
                        .padding(12)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .purple.opacity(0.35), radius: 10, x: 0, y: 6)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(info.dormitoryName)
                            .font(.title2.weight(.semibold))
                        Text(info.status.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Этаж \(info.floor)")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2), in: Capsule())
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        infoTile(title: "Комната", value: "№\(info.roomNumber)")
                        infoTile(title: "Место", value: info.bedPlace)
                    }
                    GridRow {
                        infoTile(title: "Заселён", value: dateFormatter.string(from: info.moveInDate))
                        if let daysLeft = info.daysUntilContractEnds() {
                            infoTile(title: "До конца", value: "\(daysLeft) дней")
                        } else {
                            infoTile(title: "Договор", value: dateFormatter.string(from: info.contractEndDate))
                        }
                    }
                }

                if let note = info.notes {
                    Divider().background(Color.white.opacity(0.2))
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func infoTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .kerning(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PaymentStatusCard: View {
    let info: DormitoryInfo
    let onPayment: () -> Void

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_BY")
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.currencySymbol = "BYN"
        return formatter
    }()

    private let lastPaymentFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    var body: some View {
        DormitoryGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Баланс")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(formatted(value: info.currentBalance))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                Divider().background(Color.white.opacity(0.2))

                HStack(spacing: 16) {
                    statusTile(title: "Задолженность", value: formatted(value: info.outstandingDebt), isHighlighted: info.outstandingDebt > 0)
                    if let days = info.daysUntilPaymentDue() {
                        statusTile(title: "До оплаты", value: "\(days) д.", isHighlighted: days <= 5)
                    } else {
                        statusTile(title: "Оплата", value: "Просрочено", isHighlighted: true)
                    }
                }

                if let lastPayment = info.lastPaymentDate {
                    Text("Последняя оплата: \(lastPaymentFormatter.string(from: lastPayment))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    DormitoryHaptics.play()
                    onPayment()
                } label: {
                    Label("Рекомендованный платёж: \(formatted(value: info.recommendedPaymentAmount))", systemImage: "creditcard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }

    private func formatted(value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f BYN", value)
    }

    private func statusTile(title: String, value: String, isHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2)
                .kerning(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isHighlighted ? Color.pink : Color.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HistorySection: View {
    let history: [ResidenceHistory]

    var body: some View {
        DormitoryGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("История", systemImage: "clock.arrow.circlepath")
                    .font(.headline)

                VStack(spacing: 12) {
                    ForEach(history) { item in
                        HistoryRow(item: item)
                        if item.id != history.last?.id {
                            Divider().background(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let item: ResidenceHistory

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: item.type.systemImageName)
                .font(.title2)
                .foregroundStyle(Color.purple)
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                if let description = item.description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatter.string(from: item.eventDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let amount = item.amount {
                    Text(String(format: "%.2f BYN", amount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                if let status = item.status {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ActionsSection: View {
    let actions: [DormitoryAction]
    let onAction: (DormitoryAction) -> Void

    var body: some View {
        DormitoryGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Доступные действия")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(actions) { action in
                            Button {
                                DormitoryHaptics.play()
                                onAction(action)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(systemName: action.systemImageName)
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(LinearGradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        )
                                    Text(action.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(action.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(width: 200, alignment: .leading)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct ErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        DormitoryGlassCard {
            VStack(spacing: 16) {
                Label("Не удалось загрузить данные", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Попробовать снова", action: retry)
                    .buttonStyle(GlassButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color.purple.opacity(configuration.isPressed ? 0.9 : 0.7),
                        Color.blue.opacity(configuration.isPressed ? 0.85 : 0.6)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private enum DormitoryHaptics {
    static func play() {
#if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
#endif
    }
}

#if DEBUG
#Preview {
    DormitoryView(viewModel: .preview)
}
#endif
