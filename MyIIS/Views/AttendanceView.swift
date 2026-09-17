import SwiftUI

struct AttendanceView: View {
    @EnvironmentObject private var authService: AuthenticationService
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
            .task {
                viewModel.configurePeriod(course: authService.currentUser?.education.course)
                await viewModel.loadDataIfNeeded()
            }
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

            CertificatesSection(
                certificates: viewModel.certificates,
                groupedCertificates: viewModel.groupedCertificates,
                faculty: viewModel.faculty,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.certificates],
                onRetry: reloadIfNeeded
            )

            MonthlySummarySection(
                counts: viewModel.monthlyCounts,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.summary],
                onRetry: reloadIfNeeded
            )

            AllPeriodOmissionsSection(
                semesters: viewModel.selectedSemesters,
                periodTerms: viewModel.periodTerms,
                selection: Binding(get: { viewModel.selectedTerm }, set: { viewModel.selectPeriod($0) }),
                hours: viewModel.selectedHours,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.allPeriod],
                onRetry: reloadIfNeeded
            )

            ApplicationsSection(
                applications: viewModel.applications,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.sectionErrors[.applications],
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let month: String
    let value: Int
    let maxValue: Int

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
            let ratio = CGFloat(min(max(0, value), maxValue)) / CGFloat(max(1, maxValue))
            let width = proxy.size.width * ratio
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: value > 0 ? max(4, width) : 0)
            }
        }
        .frame(height: 12)
    }
}

private struct AllPeriodOmissionsSection: View {
    let semesters: [AttendanceSemester]
    let periodTerms: [Int]
    @Binding var selection: Int
    let hours: Int
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        AttendanceCard(
            title: NSLocalizedString("attendance_period_section_title", comment: ""),
            subtitle: NSLocalizedString("attendance_all_period_subtitle", comment: ""),
            icon: "calendar"
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    periodMenu
                    Spacer(minLength: 0)
                    totalHours
                }
                VStack(alignment: .leading, spacing: 8) {
                    periodMenu
                    totalHours
                }
            }

            if isLoading && semesters.isEmpty {
                LoadingBlockView()
            } else if let errorMessage {
                SectionErrorView(message: errorMessage, action: onRetry)
            } else {
                if semesters.isEmpty {
                    Text(NSLocalizedString("attendance_all_period_empty", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 16) {
                        ForEach(semesters) { semester in
                            VStack(alignment: .leading, spacing: 8) {
                                if selection == 0 {
                                    Text(String(format: NSLocalizedString("attendance_term_format", comment: ""), semester.id))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                }
                                LazyVStack(spacing: 0) {
                                    ForEach(semester.records) { record in
                                        if record.id != semester.records.first?.id {
                                            Divider().padding(.leading, 12)
                                        }
                                        omissionRow(record.omission)
                                    }
                                }
                                .background(
                                    Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var periodTitle: String {
        selection == 0
            ? NSLocalizedString("attendance_all_period_title", comment: "")
            : String(format: NSLocalizedString("attendance_term_format", comment: ""), selection)
    }

    private var periodMenu: some View {
        Menu {
            Picker(NSLocalizedString("attendance_period_label", comment: ""), selection: $selection) {
                ForEach(periodTerms, id: \.self) { term in
                    Text(String(format: NSLocalizedString("attendance_term_format", comment: ""), term))
                        .tag(term)
                }
                Text(NSLocalizedString("attendance_all_period_title", comment: "")).tag(0)
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text(periodTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .menuOrder(.fixed)
        .accessibilityLabel(NSLocalizedString("attendance_period_label", comment: ""))
        .accessibilityValue(periodTitle)
        .accessibilityIdentifier("attendancePeriodPicker")
    }

    @ViewBuilder
    private var totalHours: some View {
        if errorMessage == nil && !(isLoading && semesters.isEmpty) {
            Text("\(hours) \(NSLocalizedString("attendance_hours_unit", comment: ""))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func omissionRow(_ omission: DisrespectfulOmission) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(omission.subject.name)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(omission.date) · \(omission.lessonTypeAbbrev)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(omission.hours) \(NSLocalizedString("attendance_hours_unit", comment: ""))")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .accessibilityElement(children: .combine)
    }
}

private struct AttendanceSemesterCard<Content: View>: View {
    @State private var isExpanded: Bool
    let title: String
    let content: Content

    init(title: String, initiallyExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 10) {
                content
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .disclosureGroupStyle(AttendanceSemesterDisclosureStyle())
    }
}

private struct AttendanceSemesterDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    configuration.label
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityValue(NSLocalizedString(
                configuration.isExpanded ? "attendance_semester_expanded" : "attendance_semester_collapsed",
                comment: ""
            ))
            if configuration.isExpanded {
                configuration.content
                    .transition(.identity)
            }
        }
        .clipped()
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
                VStack(spacing: 12) {
                    ForEach(groupedCertificates, id: \.0) { term, items in
                        AttendanceSemesterCard(
                            title: String(format: NSLocalizedString("attendance_term_format", comment: ""), Int(term) ?? 0),
                            initiallyExpanded: term == groupedCertificates.first?.0
                        ) {
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
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content

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

#Preview("Период и справки") {
    let payload = """
    [{"id":1,"dateFrom":1788220800000,"dateTo":1788566400000,"name":"Справка","term":5}]
    """
    let certificates = (try? JSONDecoder().decode([OmissionCertificate].self, from: Data(payload.utf8))) ?? []
    ScrollView {
        VStack(spacing: 20) {
            AllPeriodOmissionsSection(
                semesters: [], periodTerms: [5, 4, 3, 2, 1],
                selection: .constant(5), hours: 0, isLoading: false,
                errorMessage: nil, onRetry: {}
            )
            CertificatesSection(
                certificates: certificates, groupedCertificates: [("5", certificates), ("4", certificates)],
                faculty: nil, isLoading: false, errorMessage: nil, onRetry: {}
            )
        }
        .padding(16)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
