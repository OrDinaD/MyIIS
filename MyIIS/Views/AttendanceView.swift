import SwiftUI

struct AttendanceView: View {
    @State private var viewModel = AttendanceViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                attendanceContent
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 28)
            }
            .navigationTitle(NSLocalizedString("attendance_title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .hiddenNavigationBarBackground()
            .task { await viewModel.loadDataIfNeeded() }
            .refreshable { await viewModel.reload() }
        }
        .appBackground()
    }

    @ViewBuilder
    private var attendanceContent: some View {
        VStack(spacing: 20) {
            if viewModel.isShowingStaleDataWarning {
                StaleDataBanner(lastUpdateTime: viewModel.lastUpdateTime, errorMessage: viewModel.errorMessage) {
                    await viewModel.reload()
                }
            } else if let message = viewModel.errorMessage {
                InlineErrorBanner(message: message) {
                    Task { await viewModel.reload() }
                }
            }

            ApplicationsSection(
                applications: viewModel.applications,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.applications],
                onRetry: reloadIfNeeded
            )

            MonthlySummarySection(
                counts: viewModel.monthlyCounts,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.summary],
                onRetry: reloadIfNeeded
            )

            CertificatesSection(
                certificates: viewModel.certificates,
                groupedCertificates: viewModel.groupedCertificates,
                faculty: viewModel.faculty,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.certificates],
                onRetry: reloadIfNeeded
            )
        }
    }

    private func reloadIfNeeded() {
        Task { await viewModel.reload() }
    }
}

private struct ApplicationsSection: View {
    let applications: [OmissionApplication]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        AttendanceCard(
            title: NSLocalizedString("attendance_section_applications", comment: ""),
            subtitle: NSLocalizedString("attendance_section_applications_subtitle", comment: ""),
            icon: "doc.text.fill"
        ) {
            if isLoading && applications.isEmpty {
                LoadingBlockView()
            } else if let errorMessage, applications.isEmpty {
                SectionErrorView(message: errorMessage, action: onRetry)
            } else if applications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(NSLocalizedString("attendance_no_applications", comment: ""))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(applications) { application in
                        ApplicationRow(application: application)
                    }
                }
            }
        }
    }
}

private struct ApplicationRow: View {
    let application: OmissionApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                StatusBadge(status: application.status)
                Spacer()
                Text(application.createdDate.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LabeledValue(
                title: NSLocalizedString("attendance_period", comment: ""),
                value: "\(application.dateFrom.formattedDate) - \(application.dateTo.formattedDate)"
            )
            LabeledValue(title: NSLocalizedString("attendance_type", comment: ""), value: application.omissionCertificateType)

            if let rejection = application.rejectionReason?.trimmingCharacters(in: .whitespacesAndNewlines), !rejection.isEmpty {
                LabeledValue(title: NSLocalizedString("attendance_rejection_reason", comment: ""), value: rejection)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MonthlySummarySection: View {
    let counts: [MonthlyOmissionCount]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    private var totalCount: Int {
        counts.reduce(0) { $0 + $1.omissionCount }
    }

    var body: some View {
        AttendanceCard(
            title: NSLocalizedString("attendance_section_summary", comment: ""),
            subtitle: NSLocalizedString("attendance_section_summary_subtitle", comment: ""),
            icon: "calendar.badge.clock"
        ) {
            if isLoading && counts.isEmpty {
                LoadingBlockView()
            } else if let errorMessage, counts.isEmpty {
                SectionErrorView(message: errorMessage, action: onRetry)
            } else if counts.isEmpty {
                EmptyStateView(message: NSLocalizedString("attendance_no_summary", comment: ""), action: onRetry)
            } else {
                VStack(spacing: 14) {
                    HStack {
                        Text(NSLocalizedString("attendance_total", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(totalCount) \(NSLocalizedString("attendance_hours_unit", comment: ""))")
                            .font(.title3.weight(.semibold))
                    }

                    VStack(spacing: 10) {
                        ForEach(counts) { item in
                            MonthlyBarRow(month: item.month, value: item.omissionCount, maxValue: max(1, counts.map(\.omissionCount).max() ?? 1))
                        }
                    }
                }
            }
        }
    }
}

private struct MonthlyBarRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let month: String
    let value: Int
    let maxValue: Int
    @State private var isShowing = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    rowHeader
                    bar
                }
            } else {
                HStack(spacing: 10) {
                    Text(MonthParser.localizedTitle(from: month))
                        .font(.footnote.weight(.medium))
                        .frame(width: 80, alignment: .leading)
                    bar
                    valueText
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .accessibilityTextPair(
            label: MonthParser.localizedTitle(from: month),
            value: "\(value) \(NSLocalizedString("attendance_hours_unit", comment: ""))"
        )
        .onAppear {
            isShowing = true
        }
    }

    private var rowHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(MonthParser.localizedTitle(from: month))
                .font(.footnote.weight(.medium))
            Spacer()
            valueText
        }
    }

    private var valueText: some View {
        Text("\(value) \(NSLocalizedString("attendance_hours_unit", comment: ""))")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var bar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * CGFloat(value) / CGFloat(maxValue)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: isShowing || reduceMotion ? max(8, width) : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: isShowing)
            }
        }
        .frame(height: 12)
    }
}

private struct CertificatesSection: View {
    let certificates: [OmissionCertificate]
    let groupedCertificates: [(String, [OmissionCertificate])]
    let faculty: String?
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        AttendanceCard(
            title: NSLocalizedString("attendance_section_certificates", comment: ""),
            subtitle: NSLocalizedString("attendance_section_certificates_subtitle", comment: ""),
            icon: "cross.case.fill"
        ) {
            if let faculty, faculty != "ФИТУ" {
                InfoBanner(text: NSLocalizedString("attendance_info_banner", comment: ""))
            }

            if isLoading && certificates.isEmpty {
                LoadingBlockView()
            } else if let errorMessage, certificates.isEmpty {
                SectionErrorView(message: errorMessage, action: onRetry)
            } else if certificates.isEmpty {
                EmptyStateView(message: NSLocalizedString("attendance_no_certificates", comment: ""), action: onRetry)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedCertificates, id: \.0) { term, items in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: NSLocalizedString("attendance_term_format", comment: ""), Int(term) ?? 0))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(items) { certificate in
                                CertificateRow(certificate: certificate)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CertificateRow: View {
    let certificate: OmissionCertificate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(certificate.name)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                LabeledValue(title: NSLocalizedString("attendance_from", comment: ""), value: certificate.dateFrom.formattedDate)
                LabeledValue(title: NSLocalizedString("attendance_to", comment: ""), value: certificate.dateTo.formattedDate)
            }

            if let note = certificate.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                LabeledValue(title: NSLocalizedString("attendance_note", comment: ""), value: note)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct LabeledValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityTextPair(label: title, value: value)
    }
}

private struct AttendanceCard<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content

    @State private var isAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
        .opacity(isAppeared ? 1 : (reduceMotion ? 1 : 0.01))
        .offset(y: isAppeared || reduceMotion ? 0 : 20)
        .scaleEffect(isAppeared || reduceMotion ? 1 : 0.98)
        .onAppear {
            AccessibilitySupport.update(
                reduceMotion: reduceMotion,
                animation: .spring(response: 0.6, dampingFraction: 0.75)
            ) {
                isAppeared = true
            }
        }
        .onDisappear {
            isAppeared = false
        }
    }
}

private struct LoadingBlockView: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        let style = StatusStyle(status: status)

        return Label(style.displayText, systemImage: style.tone.iconName)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(style.background, in: Capsule(style: .continuous))
            .foregroundStyle(style.foreground)
            .accessibilityLabel(style.displayText)
    }
}

private struct StatusStyle {
    let background: Color
    let foreground: Color
    let displayText: String
    let tone: AccessibilityStatusTone

    init(status: String) {
        let normalized = status.lowercased()

        switch normalized {
        case _ where normalized.contains("одобр") || normalized.contains("approved"):
            background = Color.green.opacity(0.16)
            foreground = .green
            tone = .success
        case _ where normalized.contains("отклон") || normalized.contains("reject"):
            background = Color.red.opacity(0.16)
            foreground = .red
            tone = .error
        default:
            background = Color.orange.opacity(0.16)
            foreground = .orange
            tone = .warning
        }

        displayText = status
    }
}

private struct InlineErrorBanner: View {
    let message: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("error_partial_data", comment: ""))
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(NSLocalizedString("common_refresh", comment: ""), action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct SectionErrorView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            Button(NSLocalizedString("common_retry", comment: ""), action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct InfoBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension Date {
    var formattedDate: String {
        DateFormatter.attendanceFormatter.string(from: self)
    }

    var formattedDateTime: String {
        DateFormatter.attendanceDateTimeFormatter.string(from: self)
    }
}

private extension DateFormatter {
    static let attendanceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static let attendanceDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}

#Preview {
    AttendanceView()
}
