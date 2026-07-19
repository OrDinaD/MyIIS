import SwiftUI

struct UnauthorizedDepartmentsView: View {
    @State private var viewModel = DepartmentsViewModel()
    @State private var searchText = ""

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.tree.isEmpty {
                ProgressView("Загрузка...")
            } else if viewModel.tree.isEmpty {
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
        .task {
            if viewModel.tree.isEmpty {
                await viewModel.loadTree()
            }
        }
    }

    private var filteredDepartments: [DepartmentTreeNodeDTO] {
        if searchText.isEmpty {
            return viewModel.tree
        } else {
            return filterNodes(viewModel.tree, query: searchText.lowercased())
        }
    }

    private func filterNodes(_ nodes: [DepartmentTreeNodeDTO], query: String) -> [DepartmentTreeNodeDTO] {
        var result: [DepartmentTreeNodeDTO] = []
        for node in nodes {
            let matchesName = node.data.name.lowercased().contains(query)
            let matchesAbbrev = (node.data.abbrev ?? "").lowercased().contains(query)

            let matchedChildren = filterNodes(node.children ?? [], query: query)

            if matchesName || matchesAbbrev || !matchedChildren.isEmpty {
                let newNode = DepartmentTreeNodeDTO(
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
    let node: DepartmentTreeNodeDTO

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
    let node: DepartmentTreeNodeDTO
    @State private var viewModel = DepartmentDetailViewModel()

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

            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка сотрудников...")
                        Spacer()
                    }
                }
            } else if !viewModel.employees.isEmpty {
                Section("Сотрудники") {
                    ForEach(viewModel.employees, id: \.id) { emp in
                        let hit = EmployeeSearchHit(
                            fio: emp.getFullName(),
                            normalizedFIO: EmployeesRepository.shared.normalizeSearch(emp.getFullName()),
                            surname: emp.lastName,
                            phones: [],
                            departmentId: node.data.id,
                            departmentUrlId: node.data.urlId ?? "",
                            departmentName: node.data.name,
                            departmentAbbrev: node.data.abbrev ?? "",
                            departmentTypeId: node.data.typeId
                        )
                        NavigationLink(destination: EmployeeProfileView(hit: hit)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 12) {
                                    if let url = emp.photoLink {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            case .failure(_), .empty:
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .foregroundStyle(.gray)
                                            @unknown default:
                                                EmptyView()
                                            }
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
                                        Text(emp.getFullName())
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
        .task {
            if let urlId = node.data.urlId, viewModel.employees.isEmpty {
                await viewModel.loadEmployees(urlId: urlId)
            }
        }
    }
}
