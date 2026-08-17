//
//  OthersTabView.swift
//  MyIIS
//
// swiftlint:disable file_length
import SwiftUI
import UIKit

private enum ServicesDestination: String, CaseIterable, Identifiable, Hashable {
    case profile
    case gradebook
    case study
    case headman
    case lms
    case diploma
    case group
    case dormitory
    case library
    case announcements
    case penalties
    case activities
    case about
    case disciplines
    case studyWeeks
    case departments
    case directory
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile:
            return NSLocalizedString("tab_profile", comment: "")
        case .gradebook:
            return NSLocalizedString("services_item_markbook", comment: "")
        case .study:
            return NSLocalizedString("services_item_study", comment: "")
        case .headman:
            return NSLocalizedString("services_item_headman", comment: "")
        case .lms:
            return NSLocalizedString("services_item_lms", value: "СЭО (LMS)", comment: "")
        case .diploma:
            return NSLocalizedString("services_item_diploma", comment: "")
        case .group:
            return NSLocalizedString("services_item_group", comment: "")
        case .dormitory:
            return NSLocalizedString("services_item_dormitory", comment: "")
        case .library:
            return NSLocalizedString("services_item_library", comment: "")
        case .announcements:
            return NSLocalizedString("services_item_announcements", comment: "")
        case .penalties:
            return NSLocalizedString("services_item_penalties", comment: "")
        case .activities:
            return NSLocalizedString("services_item_activities", comment: "")
        case .about:
            return NSLocalizedString("services_item_about", comment: "")
        case .disciplines: return NSLocalizedString("services_item_disciplines", comment: "")
        case .studyWeeks: return NSLocalizedString("services_item_study_weeks", comment: "")
        case .departments: return NSLocalizedString("services_item_departments", comment: "")
        case .directory: return NSLocalizedString("services_item_directory", comment: "")
        case .support: return NSLocalizedString("services_item_support", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .profile:
            return "person.crop.circle"
        case .gradebook:
            return "book.closed.fill"
        case .study:
            return "graduationcap.fill"
        case .headman:
            return "crown.fill"
        case .lms:
            return "graduationcap"
        case .diploma:
            return "studentdesk"
        case .group:
            return "person.2"
        case .dormitory:
            return "building.2.crop.circle.fill"
        case .library:
            return "books.vertical.fill"
        case .announcements:
            return "megaphone.fill"
        case .penalties:
            return "exclamationmark.bubble.fill"
        case .activities:
            return "sparkles.rectangle.stack.fill"
        case .about:
            return "info.circle.fill"
        case .disciplines: return "list.bullet.rectangle.portrait.fill"
        case .studyWeeks: return "calendar.day.timeline.left"
        case .departments: return "building.2.fill"
        case .directory: return "book.closed.fill"
        case .support: return "wrench.and.screwdriver.fill"
        }
    }
}

struct OthersTabView: View {
    @ObservedObject private var router = AppRouter.shared
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @State private var desktopSelection: ServicesDestination?
    @State private var showLogin = false
    @State private var isGuestAccountServicesExpanded = false

    private var isAuthenticated: Bool {
        authService.currentUser != nil
    }

    private var shouldUseDesktopSplitView: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldUseDesktopSplitView {
                desktopSplitView
            } else {
                mobileStackView
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

private extension OthersTabView {
    private var mobileStackView: some View {
        NavigationStack(path: $router.servicesPath) {
            List {
                mobileServicesContent
            }
            .listStyle(.insetGrouped)
            .animation(.smooth(duration: 0.35), value: authService.currentUser?.isHeadmanOrNoteAllowed)
            .navigationTitle(NSLocalizedString("tab_services", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AppSection.self) { section in
                switch section {
                case .profile: ProfileView()
                case .gradebook: GradebookView()
                case .study: StudyView()
                case .diploma: DiplomaServiceView()
                case .group: GroupView()
                case .headman:
                    if enableBetaSections && authService.currentUser?.isHeadmanOrNoteAllowed == true {
                        HeadmanView()
                    } else {
                        EmptyView()
                    }
                case .dormitory: DormitoryView()
                case .library: LibraryServiceView()
                case .lms:
                    if enableBetaSections {
                        SEOHomeView()
                    } else {
                        EmptyView()
                    }
                case .schedule: ScheduleServiceView()
                case .disciplines: UnauthorizedDisciplinesView()
                case .studyWeeks: UnauthorizedStudyWeeksView()
                case .departments: UnauthorizedDepartmentsView()
                case .directory: UnauthorizedDirectoryView()
                case .support: SupportView()
                default: EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var mobileServicesContent: some View {
        if isAuthenticated {
            mobileProfileSection
            mobileAccountServicesSections
            mobileOpenServicesSection
            mobileAboutSection
        } else {
            mobileOpenServicesSection
            mobileSignInSection
            mobileLockedServicesSection
            mobileAboutSection
        }
    }

    private var mobileProfileSection: some View {
        Section {
            NavigationLink {
                ProfileView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(authService.currentUser?.fullName ?? NSLocalizedString("tab_profile", comment: ""))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let group = authService.currentUser?.education.group.nilIfBlank {
                            Text(String(format: NSLocalizedString("services_schedule_group_format", value: "Группа %@", comment: ""), group))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityLabel(NSLocalizedString("tab_profile", comment: ""))
            .accessibilityIdentifier("serviceLink_profile")
        }
    }

    @ViewBuilder
    private var mobileAccountServicesSections: some View {
        Section(NSLocalizedString("services_section_study", comment: "")) {
            NavigationLink(value: AppSection.gradebook) {
                serviceRow(for: .gradebook)
            }
            .accessibilityLabel(NSLocalizedString("services_item_markbook", comment: ""))
            .accessibilityIdentifier("serviceLink_gradebook")

            NavigationLink(value: AppSection.study) {
                serviceRow(for: .study)
            }
            .accessibilityLabel(NSLocalizedString("services_item_study", comment: ""))
            .accessibilityIdentifier("serviceLink_study")

            if enableBetaSections && authService.currentUser?.isHeadmanOrNoteAllowed == true {
                NavigationLink(value: AppSection.headman) {
                    serviceRow(for: .headman)
                }
                .accessibilityLabel(NSLocalizedString("services_item_headman", comment: ""))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if enableBetaSections {
                NavigationLink(value: AppSection.lms) {
                    serviceRow(for: .lms)
                }
                .accessibilityLabel(NSLocalizedString("services_item_lms", value: "СЭО (LMS)", comment: ""))
            }

            NavigationLink(value: AppSection.group) {
                serviceRow(for: .group)
            }
            .accessibilityLabel(NSLocalizedString("services_item_group", comment: ""))
            .accessibilityIdentifier("serviceLink_group")
        }

        Section(NSLocalizedString("services_section_resources", comment: "")) {
            NavigationLink(value: AppSection.dormitory) {
                serviceRow(for: .dormitory)
            }
            .accessibilityLabel(NSLocalizedString("services_item_dormitory", comment: ""))
            .accessibilityIdentifier("serviceLink_dormitory")

            NavigationLink(value: AppSection.library) {
                serviceRow(for: .library)
            }
            .accessibilityLabel(NSLocalizedString("services_item_library", comment: ""))
        }

        Section(NSLocalizedString("services_section_info", comment: "")) {
            NavigationLink {
                AnnouncementsServiceView()
            } label: {
                serviceRow(for: .announcements)
            }
            .accessibilityLabel(NSLocalizedString("services_item_announcements", comment: ""))

            NavigationLink {
                PenaltiesServiceView()
            } label: {
                serviceRow(for: .penalties)
            }
            .accessibilityLabel(NSLocalizedString("services_item_penalties", comment: ""))

            NavigationLink {
                ActivitiesServiceView()
            } label: {
                serviceRow(for: .activities)
            }
            .accessibilityLabel(NSLocalizedString("services_item_activities", comment: ""))
        }
    }

    private var mobileAboutSection: some View {
        Section {
            NavigationLink {
                AboutAppView()
            } label: {
                serviceRow(for: .about)
            }
            .accessibilityLabel(NSLocalizedString("services_item_about", comment: ""))
        }
    }

    private var mobileOpenServicesSection: some View {
        Section(NSLocalizedString("services_section_open", comment: "")) {
            NavigationLink(value: AppSection.disciplines) { serviceRow(for: .disciplines) }
            NavigationLink(value: AppSection.studyWeeks) { serviceRow(for: .studyWeeks) }
            NavigationLink(value: AppSection.departments) { serviceRow(for: .departments) }
            NavigationLink(value: AppSection.directory) { serviceRow(for: .directory) }
            NavigationLink(value: AppSection.support) { serviceRow(for: .support) }
        }
    }

    private var mobileSignInSection: some View {
        Section {
            Button {
                showLogin = true
            } label: {
                ServicesSignInPromptRow()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("servicesSignInPrompt")
        }
    }

    private var mobileLockedServicesSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isGuestAccountServicesExpanded) {
                ForEach(lockedDestinations) { destination in
                    lockedServiceButton(for: destination)
                }
            } label: {
                ServicesLockedHeader()
            }
            .tint(.secondary)
            .accessibilityIdentifier("lockedAccountServicesDisclosure")
        }
    }

    private var desktopSplitView: some View {
        NavigationSplitView {
            List(selection: $desktopSelection) {
                desktopServicesContent
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("tab_services", comment: ""))
        } detail: {
            NavigationStack {
                Group {
                    if let destination = desktopSelection {
                        destinationView(for: destination)
                    } else {
                        ServicesPlaceholderView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appBackground()
            }
            .id(desktopSelection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var desktopServicesContent: some View {
        if isAuthenticated {
            Section {
                serviceRow(for: .profile)
                    .tag(ServicesDestination.profile)
            }
            desktopAccountServicesSections
            desktopOpenServicesSection
            Section {
                serviceRow(for: .about)
                    .tag(ServicesDestination.about)
            }
        } else {
            desktopOpenServicesSection
            Section {
                Button {
                    showLogin = true
                } label: {
                    ServicesSignInPromptRow()
                }
                .buttonStyle(.plain)
                .tag(nil as ServicesDestination?)
            }
            desktopLockedServicesSection
            Section {
                serviceRow(for: .about)
                    .tag(ServicesDestination.about)
            }
        }
    }

    @ViewBuilder
    private var desktopAccountServicesSections: some View {
        Section(NSLocalizedString("services_section_study", comment: "")) {
            ForEach(studyDestinations) { destination in
                serviceRow(for: destination)
                    .tag(destination)
            }
        }

        Section(NSLocalizedString("services_section_resources", comment: "")) {
            ForEach(resourceDestinations) { destination in
                serviceRow(for: destination)
                    .tag(destination)
            }
        }

        Section(NSLocalizedString("services_section_info", comment: "")) {
            ForEach(infoDestinations) { destination in
                serviceRow(for: destination)
                    .tag(destination)
            }
        }
    }

    private var desktopOpenServicesSection: some View {
        Section(NSLocalizedString("services_section_open", comment: "")) {
            ForEach(openDestinations) { destination in
                serviceRow(for: destination)
                    .tag(destination)
            }
        }
    }

    private var desktopLockedServicesSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isGuestAccountServicesExpanded) {
                ForEach(lockedDestinations) { destination in
                    lockedServiceButton(for: destination)
                        .tag(nil as ServicesDestination?)
                }
            } label: {
                ServicesLockedHeader()
            }
            .tint(.secondary)
        }
    }

    private var studyDestinations: [ServicesDestination] {
        var values: [ServicesDestination] = [.gradebook, .study]
        if enableBetaSections && authService.currentUser?.isHeadmanOrNoteAllowed == true {
            values.append(.headman)
        }
        if enableBetaSections {
            values.append(.lms)
        }
        values.append(.group)
        return values
    }

    private var resourceDestinations: [ServicesDestination] {
        [.dormitory, .library]
    }

    private var infoDestinations: [ServicesDestination] {
        [.announcements, .penalties, .activities]
    }

    private var openDestinations: [ServicesDestination] {
        [.disciplines, .studyWeeks, .departments, .directory, .support]
    }

    private var lockedDestinations: [ServicesDestination] {
        studyDestinations + resourceDestinations + infoDestinations
    }

    @ViewBuilder
    private func destinationView(for destination: ServicesDestination) -> some View {
        switch destination {
        case .profile:
            ProfileView()
        case .lms:
            if enableBetaSections {
                SEOHomeView()
            } else {
                EmptyView()
            }
        case .announcements, .penalties, .activities, .about:
            infoDestinationView(for: destination)
        case .disciplines, .studyWeeks, .departments, .directory, .support:
            openDestinationView(for: destination)
        default:
            studyOrResourceDestinationView(for: destination)
        }
    }

    @ViewBuilder
    private func openDestinationView(for destination: ServicesDestination) -> some View {
        switch destination {
        case .disciplines:
            UnauthorizedDisciplinesView()
        case .studyWeeks:
            UnauthorizedStudyWeeksView()
        case .departments:
            UnauthorizedDepartmentsView()
        case .directory:
            UnauthorizedDirectoryView()
        case .support:
            SupportView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func studyOrResourceDestinationView(for destination: ServicesDestination) -> some View {
        switch destination {
        case .gradebook:
            GradebookView()
        case .study:
            StudyView()
        case .headman:
            if enableBetaSections && authService.currentUser?.isHeadmanOrNoteAllowed == true {
                HeadmanView()
            } else {
                EmptyView()
            }
        case .diploma:
            DiplomaServiceView()
        case .group:
            GroupView()
        case .dormitory:
            DormitoryView()
        case .library:
            LibraryServiceView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func infoDestinationView(for destination: ServicesDestination) -> some View {
        switch destination {
        case .announcements:
            AnnouncementsServiceView()
        case .penalties:
            PenaltiesServiceView()
        case .activities:
            ActivitiesServiceView()
        case .about:
            AboutAppView()
        default:
            EmptyView()
        }
    }

    private func serviceRow(for destination: ServicesDestination) -> some View {
        ServiceRow(icon: destination.icon, title: destination.title)
            .accessibilityLabel(destination.title)
    }

    private func lockedServiceButton(for destination: ServicesDestination) -> some View {
        Button {
            showLogin = true
        } label: {
            ServicesLockedRow(icon: destination.icon, title: destination.title)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.title)
        .accessibilityHint(NSLocalizedString("services_locked_hint", comment: ""))
    }
}

private struct ServicesPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            NSLocalizedString("tab_services", comment: ""),
            systemImage: "rectangle.split.2x1",
            description: Text(NSLocalizedString("services_placeholder_description", comment: ""))
        )
    }
}

private struct ServiceRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OthersTabView()
        .environmentObject(AuthenticationService.shared)
}
