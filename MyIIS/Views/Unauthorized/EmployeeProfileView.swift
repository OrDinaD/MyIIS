import SwiftUI

struct EmployeeProfileView: View {
    let basicEmployee: DepartmentEmployeeDetail

    @State private var detailedEmployee: DepartmentEmployeeDetail?
    @State private var isLoading = false

    var employee: DepartmentEmployeeDetail {
        detailedEmployee ?? basicEmployee
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    if let photo = employee.photoLink, let url = URL(string: photo.replacingOccurrences(of: "http://", with: "https://").replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")) {
                        CachedAsyncImage(url: url, maxPixelSize: 240) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundStyle(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(employee.fio)
                            .font(.title3.weight(.bold))

                        if let degree = employee.degree, !degree.isEmpty {
                            Text(degree)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let rank = employee.rank, !rank.isEmpty {
                            Text(rank)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let email = employee.email, !email.isEmpty {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.blue)
                                Text(email)
                                    .tint(.blue)
                            }
                            .font(.subheadline)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            if let positions = employee.jobPositions, !positions.isEmpty {
                Section("Должности") {
                    ForEach(positions, id: \.jobPosition) { pos in
                        VStack(alignment: .leading, spacing: 4) {
                            if let title = pos.jobPosition {
                                Text(title.capitalized)
                                    .font(.headline)
                            }
                            if let dept = pos.department {
                                Text(dept)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let contacts = pos.contacts, !contacts.isEmpty {
                                ForEach(contacts, id: \.phoneNumber) { contact in
                                    if let phone = contact.phoneNumber {
                                        HStack {
                                            Image(systemName: "phone.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                            Text(phone)
                                        }
                                        .font(.subheadline)
                                    }
                                    if let address = contact.address {
                                        HStack(alignment: .top) {
                                            Image(systemName: "building.2.fill")
                                                .foregroundStyle(.orange)
                                                .font(.caption)
                                            Text(address)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let reading = employee.readingCourses, !reading.isEmpty {
                Section("Читаемые курсы") {
                    ForEach(reading, id: \.id) { course in
                        VStack(alignment: .leading) {
                            Text(course.disciplineName ?? "")
                                .font(.body)
                            if let abbrev = course.disciplineAbbrev {
                                Text(abbrev)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let additional = employee.additionalInformation, !additional.isEmpty {
                ForEach(additional, id: \.idType) { info in
                    if let typeName = info.nameType, let content = info.content, !content.isEmpty {
                        Section(typeName) {
                            Text(content)
                                .font(.body)
                        }
                    }
                }
            }
        }
        .navigationTitle(employee.lastName)
        .transparentInlineNavigationBar()
        .onAppear {
            if detailedEmployee == nil, let urlId = basicEmployee.urlId {
                isLoading = true
                Task {
                    if let detailed = await DepartmentsService.shared.fetchEmployeeDetails(for: urlId) {
                        detailedEmployee = detailed
                    }
                    isLoading = false
                }
            }
        }
    }
}
