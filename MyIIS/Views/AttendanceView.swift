//
//  AttendanceView.swift
//  MyIIS
//
//  Updated by OpenAI Assistant on 09.12.2025.
//

import SwiftUI

struct AttendanceView: View {

    @StateObject private var viewModel = AttendanceViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let error = viewModel.errorMessage, viewModel.applications.isEmpty && viewModel.certificates.isEmpty {
                        ErrorStateView(message: error) {
                            Task { await viewModel.reload() }
                        }
                    }

                    MonthlySummarySection(counts: viewModel.monthlyCounts,
                                          isLoading: viewModel.isLoading,
                                          onRetry: reloadIfNeeded)

                    ApplicationsSection(applications: viewModel.applications,
                                        isLoading: viewModel.isLoading,
                                        onRetry: reloadIfNeeded)

                    CertificatesSection(certificates: viewModel.certificates,
                                        faculty: viewModel.faculty,
                                        isLoading: viewModel.isLoading,
                                        onRetry: reloadIfNeeded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(LinearGradient(colors: [
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea())
            .navigationTitle("Пропуски")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadDataIfNeeded() }
            .refreshable { await viewModel.reload() }
        }
    }

    private func reloadIfNeeded() {
        Task { await viewModel.reload() }
    }
}

// MARK: - Sections

private struct ApplicationsSection: View {
    let applications: [OmissionApplication]
    let isLoading: Bool
    let onRetry: () -> Void

    private let columns: [CGFloat] = [130, 120, 190, 160, 200]

    var body: some View {
        AttendanceCard(title: "Заявления по ОРВИ", icon: "doc.text.fill") {
            if isLoading && applications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if applications.isEmpty {
                EmptyStateView(message: "У вас пока нет заявлений по ОРВИ.", action: onRetry)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        tableHeader
                        Divider()
                        ForEach(applications) { application in
                            tableRow(for: application)
                            Divider()
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 16) {
            Text("Статус").font(.caption).fontWeight(.semibold).frame(width: columns[0], alignment: .leading)
            Text("Дата подачи").font(.caption).fontWeight(.semibold).frame(width: columns[1], alignment: .leading)
            Text("Период действия").font(.caption).fontWeight(.semibold).frame(width: columns[2], alignment: .leading)
            Text("Документ").font(.caption).fontWeight(.semibold).frame(width: columns[3], alignment: .leading)
            Text("Причина отказа").font(.caption).fontWeight(.semibold).frame(width: columns[4], alignment: .leading)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }

    private func tableRow(for application: OmissionApplication) -> some View {
        HStack(spacing: 16) {
            StatusBadge(status: application.status)
                .frame(width: columns[0], alignment: .leading)

            Text(application.createdDate.formattedDate)
                .frame(width: columns[1], alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("С: \(application.dateFrom.formattedDate)")
                Text("По: \(application.dateTo.formattedDate)")
            }
            .frame(width: columns[2], alignment: .leading)

            Text(application.omissionCertificateType)
                .frame(width: columns[3], alignment: .leading)

            Text(application.rejectionReason ?? "—")
                .foregroundStyle(application.rejectionReason == nil ? .secondary : .primary)
                .frame(width: columns[4], alignment: .leading)
        }
        .font(.footnote)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MonthlySummarySection: View {
    let counts: [MonthlyOmissionCount]
    let isLoading: Bool
    let onRetry: () -> Void

    private var totalCount: Int {
        counts.reduce(0) { $0 + $1.omissionCount }
    }

    var body: some View {
        AttendanceCard(title: "Пропуски по неуважительной причине", icon: "calendar") {
            if isLoading && counts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if counts.isEmpty {
                EmptyStateView(message: "Нет статистики по неуважительным пропускам за текущий семестр.", action: onRetry)
            } else {
                VStack(spacing: 16) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: max(min(counts.count, 4), 1)), spacing: 16) {
                        ForEach(counts) { item in
                            VStack(spacing: 8) {
                                Text(item.month)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                Text("\(item.omissionCount) ч.")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Divider()

                    HStack {
                        Label("Всего за семестр", systemImage: "sum")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(totalCount) ч.")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct CertificatesSection: View {
    let certificates: [OmissionCertificate]
    let faculty: String?
    let isLoading: Bool
    let onRetry: () -> Void

    private let columns: [CGFloat] = [180, 160, 220]

    var body: some View {
        AttendanceCard(title: "Информация о справках", icon: "doc.plaintext") {
            if let faculty, faculty != "ФИТУ" {
                InfoBanner(text: "При пропусках по болезни необходимо предоставить медицинские справки в деканат в течение 3 дней.")
            }

            if isLoading && certificates.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if certificates.isEmpty {
                EmptyStateView(message: "У вас нет загруженных справок.", action: onRetry)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        certificateHeader
                        Divider()
                        ForEach(groupedCertificates(), id: \.0) { term, items in
                            TermHeader(term: term)
                            ForEach(items) { certificate in
                                certificateRow(certificate)
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var certificateHeader: some View {
        HStack(spacing: 16) {
            Text("Тип документа")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: columns[0], alignment: .leading)
            Text("Период действия")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: columns[1], alignment: .center)
            Text("Примечание")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: columns[2], alignment: .leading)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }

    private func certificateRow(_ certificate: OmissionCertificate) -> some View {
        HStack(spacing: 16) {
            Text(certificate.name)
                .frame(width: columns[0], alignment: .leading)
            VStack(spacing: 4) {
                Text("Начало: \(certificate.dateFrom.formattedDate)")
                    .fontWeight(.semibold)
                Text("Окончание: \(certificate.dateTo.formattedDate)")
                    .foregroundStyle(.secondary)
            }
            .frame(width: columns[1], alignment: .center)
            Text(certificate.note?.isEmpty == false ? certificate.note! : "—")
                .foregroundStyle(certificate.note?.isEmpty == false ? .primary : .secondary)
                .frame(width: columns[2], alignment: .leading)
        }
        .font(.footnote)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func groupedCertificates() -> [(String, [OmissionCertificate])]
    {
        let grouped = Dictionary(grouping: certificates) { $0.term }
        let sortedTerms = grouped.keys.sorted { (lhs, rhs) -> Bool in
            let leftValue = Int(lhs) ?? 0
            let rightValue = Int(rhs) ?? 0
            return leftValue > rightValue
        }
        return sortedTerms.map { term in
            let items = grouped[term, default: []].sorted { $0.dateFrom > $1.dateFrom }
            return (term, items)
        }
    }
}

// MARK: - Supporting Views

private struct AttendanceCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        )
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        let style = StatusStyle(status: status)
        return Text(style.displayText)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(style.background, in: Capsule(style: .continuous))
            .foregroundStyle(style.foreground)
    }
}

private struct StatusStyle {
    let background: Color
    let foreground: Color
    let displayText: String

    init(status: String) {
        let normalized = status.lowercased()
        switch normalized {
        case _ where normalized.contains("одобр"):
            background = Color.green.opacity(0.15)
            foreground = .green
        case _ where normalized.contains("отклон"):
            background = Color.red.opacity(0.15)
            foreground = .red
        default:
            background = Color.orange.opacity(0.15)
            foreground = .orange
        }
        displayText = status
    }
}

private struct ErrorStateView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Не удалось загрузить данные")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Повторить попытку", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .systemBackground)))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

private struct EmptyStateView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Обновить", action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InfoBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TermHeader: View {
    let term: String

    var body: some View {
        Text("\(term) семестр")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .padding(.horizontal, 12)
    }
}

private extension Date {
    var formattedDate: String {
        DateFormatter.attendanceFormatter.string(from: self)
    }
}

private extension DateFormatter {
    static let attendanceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

#Preview {
    AttendanceView()
}
