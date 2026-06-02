//
//  OthersTabView.swift
//  MyIIS
//
import SwiftUI
import UIKit

private enum ServicesDestination: String, Identifiable, Hashable {
    case gradebook
    case study
    case schedule
    case headman
    case diploma
    case group
    case dormitory
    case library
    case announcements
    case penalties
    case activities
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradebook:
            return NSLocalizedString("services_item_markbook", comment: "")
        case .study:
            return NSLocalizedString("services_item_study", comment: "")
        case .schedule:
            return NSLocalizedString("services_item_schedule", comment: "")
        case .headman:
            return NSLocalizedString("services_item_headman", comment: "")
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
        }
    }

    var icon: String {
        switch self {
        case .gradebook:
            return "book.closed.fill"
        case .study:
            return "graduationcap.fill"
        case .schedule:
            return "calendar"
        case .headman:
            return "crown.fill"
        case .diploma:
            return "studentdesk"
        case .group:
            return "person.3.fill"
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
        }
    }
}

struct OthersTabView: View {
    @StateObject private var router = AppRouter.shared
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var desktopSelection: ServicesDestination?

    private var shouldUseDesktopSplitView: Bool {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return false
        }
        return horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldUseDesktopSplitView {
                desktopSplitView
            } else {
                mobileStackView
            }
        }
    }

    private var mobileStackView: some View {
        NavigationStack(path: $router.servicesPath) {
            List {
                Section(NSLocalizedString("services_section_study", comment: "")) {
                    NavigationLink(value: AppSection.gradebook) {
                        serviceRow(for: .gradebook)
                    }
                    .accessibilityLabel(NSLocalizedString("services_item_markbook", comment: ""))

                    NavigationLink(value: AppSection.study) {
                        serviceRow(for: .study)
                    }
                    .accessibilityLabel(NSLocalizedString("services_item_study", comment: ""))

                    if enableBetaSections {
                        NavigationLink(value: AppSection.schedule) {
                            serviceRow(for: .schedule)
                        }
                        .accessibilityLabel(NSLocalizedString("services_item_schedule", comment: ""))

                        NavigationLink(value: AppSection.headman) {
                            serviceRow(for: .headman)
                        }
                        .accessibilityLabel(NSLocalizedString("services_item_headman", comment: ""))
                    }

                    NavigationLink(value: AppSection.diploma) {
                        serviceRow(for: .diploma)
                    }
                    .accessibilityLabel(NSLocalizedString("services_item_diploma", comment: ""))

                    NavigationLink(value: AppSection.group) {
                        serviceRow(for: .group)
                    }
                    .accessibilityLabel(NSLocalizedString("services_item_group", comment: ""))
                }

                Section(NSLocalizedString("services_section_resources", comment: "")) {
                    NavigationLink(value: AppSection.dormitory) {
                        serviceRow(for: .dormitory)
                    }
                    .accessibilityLabel(NSLocalizedString("services_item_dormitory", comment: ""))

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

                Section {
                    NavigationLink {
                        AboutAppView()
                    } label: {
                        serviceRow(for: .about)
                    }
                    .accessibilityLabel(NSLocalizedString("services_item_about", comment: ""))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("tab_services", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .hiddenNavigationBarBackground()
            .navigationDestination(for: AppSection.self) { section in
                switch section {
                case .gradebook: GradebookView()
                case .study: StudyView()
                case .diploma: DiplomaServiceView()
                case .group: GroupView()
                case .headman: HeadmanView()
                case .dormitory: DormitoryView()
                case .library: LibraryServiceView()
                case .lms: LMSLoginView()
                case .schedule: ScheduleServiceView()
                default: EmptyView()
                }
            }
        }
    }

    private var desktopSplitView: some View {
        NavigationSplitView {
            List(selection: $desktopSelection) {
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

                Section {
                    serviceRow(for: .about)
                        .tag(ServicesDestination.about)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("tab_services", comment: ""))
        } detail: {
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
        .navigationSplitViewStyle(.balanced)
    }

    private var studyDestinations: [ServicesDestination] {
        var values: [ServicesDestination] = [.gradebook, .study]
        if enableBetaSections {
            values.append(contentsOf: [.schedule, .headman])
        }
        values.append(contentsOf: [.diploma, .group])
        return values
    }

    private var resourceDestinations: [ServicesDestination] {
        [.dormitory, .library]
    }

    private var infoDestinations: [ServicesDestination] {
        [.announcements, .penalties, .activities]
    }

    @ViewBuilder
    private func destinationView(for destination: ServicesDestination) -> some View {
        switch destination {
        case .announcements, .penalties, .activities, .about:
            infoDestinationView(for: destination)
        default:
            studyOrResourceDestinationView(for: destination)
        }
    }

    @ViewBuilder
    private func studyOrResourceDestinationView(for destination: ServicesDestination) -> some View {
        switch destination {
        case .gradebook:
            GradebookView()
        case .study:
            StudyView()
        case .schedule:
            ScheduleServiceView()
        case .headman:
            HeadmanView()
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
}

private struct ServicesPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            NSLocalizedString("tab_services", comment: ""),
            systemImage: "rectangle.split.2x1",
            description: Text("Выберите сервис в списке слева")
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
}
