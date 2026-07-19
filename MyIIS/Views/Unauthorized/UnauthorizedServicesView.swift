import SwiftUI

struct UnauthorizedServicesView: View {
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showLogin = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill.badge.plus")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("services_sign_in_title", comment: ""))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(NSLocalizedString("unauthorized_all_features_subtitle", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(NSLocalizedString("services_section_study", comment: "")) {
                    NavigationLink(destination: UnauthorizedDisciplinesView()) {
                        serviceRow(icon: "list.bullet.rectangle.portrait.fill", title: NSLocalizedString("services_item_disciplines", comment: ""))
                    }
                    NavigationLink(destination: UnauthorizedStudyWeeksView()) {
                        serviceRow(icon: "calendar.day.timeline.left", title: NSLocalizedString("services_item_study_weeks", comment: ""))
                    }
                }

                Section(NSLocalizedString("services_section_info", comment: "")) {
                    NavigationLink(destination: UnauthorizedDepartmentsView()) {
                        serviceRow(icon: "building.2.fill", title: NSLocalizedString("services_item_departments", comment: ""))
                    }
                    NavigationLink(destination: UnauthorizedDirectoryView()) {
                        serviceRow(icon: "book.closed.fill", title: NSLocalizedString("services_item_directory", comment: ""))
                    }
                }

                Section("Документы и техподдержка") {
                    NavigationLink(destination: SupportView()) {
                        serviceRow(icon: "wrench.and.screwdriver.fill", title: "Техническая поддержка")
                    }
                }

                Section(NSLocalizedString("unauthorized_services_locked_section", comment: "")) {
                    lockedServiceRow(icon: "book.closed.fill", title: NSLocalizedString("services_item_markbook", comment: ""))
                    lockedServiceRow(icon: "calendar", title: NSLocalizedString("services_item_schedule", comment: ""))
                    lockedServiceRow(icon: "graduationcap.fill", title: NSLocalizedString("services_item_study", comment: ""))
                    lockedServiceRow(icon: "person.2", title: NSLocalizedString("services_item_group", comment: ""))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("tab_services", comment: ""))
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    private func serviceRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func lockedServiceRow(icon: String, title: String) -> some View {
        Button {
            showLogin = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )

                Text(title)
                    .font(.body.weight(.regular))
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
