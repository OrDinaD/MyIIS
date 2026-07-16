import SwiftUI

struct UnauthorizedDepartmentsView: View {
    @StateObject private var service = DepartmentsService.shared
    @State private var searchText = ""

    var body: some View {
        Group {
            if service.isLoading && service.departments.isEmpty {
                ProgressView("Загрузка...")
            } else if service.departments.isEmpty {
                ContentUnavailableView("Нет данных", systemImage: "building.2.crop.circle.fill", description: Text("Не удалось загрузить список подразделений."))
            } else {
                List(filteredDepartments, children: \.children) { node in
                    DepartmentRow(node: node)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Подразделения")
        .transparentInlineNavigationBar()
        .searchable(text: $searchText, prompt: "Поиск подразделений")
        .onAppear {
            if service.departments.isEmpty {
                service.loadMockData()
            }
        }
    }

    private var filteredDepartments: [DepartmentNode] {
        if searchText.isEmpty {
            return service.departments
        } else {
            return filterNodes(service.departments, query: searchText.lowercased())
        }
    }

    private func filterNodes(_ nodes: [DepartmentNode], query: String) -> [DepartmentNode] {
        var result: [DepartmentNode] = []
        for node in nodes {
            let matchesName = node.data.name.lowercased().contains(query)
            let matchesAbbrev = node.data.abbrev?.lowercased().contains(query) ?? false

            let matchedChildren = filterNodes(node.children ?? [], query: query)

            if matchesName || matchesAbbrev || !matchedChildren.isEmpty {
                let newNode = DepartmentNode(
                    data: node.data,
                    children: matchedChildren.isEmpty ? nil : matchedChildren
                )
                result.append(newNode)
            }
        }
        return result
    }
}

private struct DepartmentRow: View {
    let node: DepartmentNode

    var body: some View {
        NavigationLink(destination: DepartmentDetailView(node: node)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.data.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                if let abbrev = node.data.abbrev, abbrev != node.data.name {
                    Text(abbrev)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct DepartmentDetailView: View {
    let node: DepartmentNode
    @State private var detailedEmployees: [DepartmentEmployeeDetail] = []
    @State private var isLoadingEmployees = false

    var body: some View {
        List {
            Section("Информация") {
                if let abbrev = node.data.abbrev {
                    LabeledContent("Аббревиатура", value: abbrev)
                }
                if let code = node.data.code {
                    LabeledContent("Код", value: code)
                }
            }

            if isLoadingEmployees {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка сотрудников...")
                        Spacer()
                    }
                }
            } else if !detailedEmployees.isEmpty {
                Section("Сотрудники") {
                    ForEach(detailedEmployees) { emp in
                        NavigationLink(destination: EmployeeProfileView(basicEmployee: emp)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 12) {
                                    if let photo = emp.photoLink, let url = URL(string: photo.replacingOccurrences(of: "http://", with: "https://").replacingOccurrences(of: "null/", with: "https://iis.bsuir.by/")) {
                                        CachedAsyncImage(url: url, maxPixelSize: 160) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.circle.fill")
                                                .foregroundStyle(.gray)
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                            .foregroundStyle(.gray)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(emp.fio)
                                            .font(.headline)

                                        if let positions = emp.jobPositions, !positions.isEmpty {
                                            ForEach(positions, id: \.jobPosition) { pos in
                                                if let title = pos.jobPosition {
                                                    Text(title)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }

                                if let email = emp.email, !email.isEmpty {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                        Text(email)
                                            .font(.subheadline)
                                    }
                                    .padding(.top, 2)
                                }

                                if let positions = emp.jobPositions {
                                    ForEach(positions, id: \.jobPosition) { pos in
                                        if let contacts = pos.contacts {
                                            ForEach(contacts, id: \.phoneNumber) { contact in
                                                if let phone = contact.phoneNumber {
                                                    HStack {
                                                        Image(systemName: "phone.fill")
                                                            .foregroundStyle(.green)
                                                            .font(.caption)
                                                        Text(phone)
                                                            .font(.subheadline)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            } else if let employees = node.data.employees, !employees.isEmpty {
                Section("Сотрудники (кратко)") {
                    ForEach(employees, id: \.fio) { emp in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(emp.fio)
                                .font(.headline)

                            if let phones = emp.phoneNumbers {
                                ForEach(phones, id: \.self) { phone in
                                    Text(phone)
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(node.data.abbrev ?? node.data.name)
        .transparentInlineNavigationBar()
        .onAppear {
            if let urlId = node.data.urlId, detailedEmployees.isEmpty {
                isLoadingEmployees = true
                Task {
                    let emps = await DepartmentsService.shared.fetchEmployees(for: urlId)
                    detailedEmployees = emps
                    isLoadingEmployees = false
                }
            }
        }
    }
}
