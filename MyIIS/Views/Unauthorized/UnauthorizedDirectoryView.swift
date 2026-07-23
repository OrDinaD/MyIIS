import SwiftUI

struct UnauthorizedDirectoryView: View {
    @State private var viewModel = EmployeesDirectoryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.searchResults.isEmpty {
                ProgressView("Поиск...")
            } else if viewModel.searchResults.isEmpty {
                if viewModel.searchText.isEmpty {
                    ContentUnavailableView("Справочник", systemImage: "magnifyingglass", description: Text("Введите имя, кафедру или номер для поиска"))
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            } else {
                List(viewModel.searchResults) { hit in
                    NavigationLink(destination: EmployeeProfileView(hit: hit)) {
                        EmployeeSearchHitRow(hit: hit)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Справочник")
        .transparentInlineNavigationBar()
        .searchable(text: $viewModel.searchText, prompt: "Кого ищем?")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.performSearch()
        }
        .task {
            if viewModel.searchResults.isEmpty && viewModel.searchText.isEmpty {
                await viewModel.loadInitial()
            }
        }
    }
}

private struct EmployeeSearchHitRow: View {
    let hit: EmployeeSearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hit.fio)
                .font(.headline)

            HStack {
                Text(hit.departmentAbbrev)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !hit.phones.isEmpty {
                ForEach(hit.phones, id: \.self) { phone in
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
