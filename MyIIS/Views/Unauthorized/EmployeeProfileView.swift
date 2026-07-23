import SwiftUI

struct EmployeeProfileView: View {
    let hit: EmployeeSearchHit
    @State private var viewModel = EmployeeProfileViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Загрузка профиля...")
                    Spacer()
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Ошибка",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if let profile = viewModel.profile {
                profileContent(profile)
            }
        }
        .navigationTitle(hit.fio)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: hit.id) {
            await viewModel.loadProfile(for: hit)
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: EmployeeProfile) -> some View {
        profileHeader(profile)
        emailSection(profile.email)
        positionsSection(profile.positions)
        coursesSection(profile.readingCourses)
        additionalInformationSections(profile.additionalSections)
    }

    private func profileHeader(_ profile: EmployeeProfile) -> some View {
        Section {
            HStack(spacing: 16) {
                profileImage(url: profile.photoURL)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name.getFullName())
                        .font(.title3.bold())

                    if let degree = profile.degreeAbbreviation {
                        Text(degree)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let rank = profile.rank {
                        Text(rank)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func emailSection(_ email: String?) -> some View {
        if let email, !email.isEmpty {
            Section {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.blue)
                    Text(email)
                }
            }
        }
    }

    @ViewBuilder
    private func positionsSection(_ positions: [EmployeePosition]) -> some View {
        if !positions.isEmpty {
            Section("Должности") {
                ForEach(positions, id: \.self) { position in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(position.title)
                            .font(.headline)
                        Text(position.departmentName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(position.contacts, id: \.self) { contact in
                            contactRows(contact)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func coursesSection(_ courses: [String]) -> some View {
        if !courses.isEmpty {
            Section("Читаемые курсы") {
                ForEach(courses, id: \.self) { course in
                    Text(course)
                }
            }
        }
    }

    private func additionalInformationSections(
        _ sections: [EmployeeInfoSection]
    ) -> some View {
        ForEach(sections) { section in
            Section(section.title) {
                Text(section.textContent)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func profileImage(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    profileImagePlaceholder
                @unknown default:
                    profileImagePlaceholder
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        } else {
            profileImagePlaceholder
                .frame(width: 88, height: 88)
        }
    }

    private var profileImagePlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundStyle(.gray)
    }

    @ViewBuilder
    private func contactRows(_ contact: EmployeeContact) -> some View {
        if let phone = contact.phone {
            HStack {
                Image(systemName: "phone.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(phone)
                    .font(.subheadline)
            }
        }
        if let address = contact.address {
            HStack(alignment: .top) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text(address)
                    .font(.subheadline)
            }
        }
    }
}
