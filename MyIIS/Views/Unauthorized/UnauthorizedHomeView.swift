import SwiftUI

struct UnauthorizedHomeView: View {
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            List {
                signInSection
                publicSections
                accountSections
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("tab_home", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .hiddenNavigationBarBackground()
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    private var signInSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.accentColor, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("unauthorized_app_title", comment: ""))
                            .font(.title3.weight(.semibold))
                        Text(NSLocalizedString("unauthorized_guest_access", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(NSLocalizedString("unauthorized_home_sign_in_message", comment: ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showLogin = true
                } label: {
                    Label(NSLocalizedString("services_sign_in_title", comment: ""), systemImage: "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical, 8)
        }
    }

    private var publicSections: some View {
        Section(NSLocalizedString("unauthorized_available_without_sign_in", comment: "")) {
            NavigationLink {
                UnauthorizedRatingView()
            } label: {
                HomeServiceRow(
                    icon: "chart.bar.fill",
                    tint: .blue,
                    title: NSLocalizedString("unauthorized_rating_title", comment: ""),
                    subtitle: NSLocalizedString("unauthorized_rating_subtitle", comment: "")
                )
            }

            NavigationLink {
                UnauthorizedDisciplinesView()
            } label: {
                HomeServiceRow(
                    icon: "list.bullet.rectangle.portrait.fill",
                    tint: .indigo,
                    title: NSLocalizedString("services_item_disciplines", comment: ""),
                    subtitle: NSLocalizedString("unauthorized_disciplines_subtitle", comment: "")
                )
            }

            NavigationLink {
                UnauthorizedStudyWeeksView()
            } label: {
                HomeServiceRow(
                    icon: "calendar.day.timeline.left",
                    tint: .orange,
                    title: NSLocalizedString("services_item_study_weeks", comment: ""),
                    subtitle: NSLocalizedString("unauthorized_study_weeks_subtitle", comment: "")
                )
            }

            NavigationLink {
                UnauthorizedDirectoryView()
            } label: {
                HomeServiceRow(
                    icon: "book.closed.fill",
                    tint: .green,
                    title: NSLocalizedString("services_item_directory", comment: ""),
                    subtitle: NSLocalizedString("unauthorized_directory_subtitle", comment: "")
                )
            }
        }
    }

    private var accountSections: some View {
        Section(NSLocalizedString("unauthorized_after_sign_in", comment: "")) {
            lockedRow(icon: "calendar", title: NSLocalizedString("services_item_schedule", comment: ""))
            lockedRow(icon: "book.closed.fill", title: NSLocalizedString("services_item_markbook", comment: ""))
            lockedRow(icon: "person.3.fill", title: NSLocalizedString("services_item_group", comment: ""))
        }
    }

    private func lockedRow(icon: String, title: String) -> some View {
        Button {
            showLogin = true
        } label: {
            HStack(spacing: 12) {
                HomeIcon(icon: icon, tint: .secondary)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(NSLocalizedString("services_locked_hint", comment: ""))
    }
}

private struct HomeServiceRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HomeIcon(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HomeIcon: View {
    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
