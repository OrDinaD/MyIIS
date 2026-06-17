import SwiftUI

struct UnauthorizedDirectoryView: View {
    @StateObject private var service = PhoneBookService.shared
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    ProgressView("Поиск...")
                } else if service.entries.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView("Справочник", systemImage: "magnifyingglass", description: Text("Введите имя, кафедру или номер для поиска"))
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    List(service.entries) { entry in
                        PhoneBookRow(entry: entry)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Справочник")
            .searchable(text: $searchText, prompt: "Кого ищем?")
            .onChange(of: searchText) { _, newValue in
                if newValue.count > 2 || newValue.isEmpty {
                    Task {
                        await service.search(query: newValue)
                    }
                }
            }
            .onAppear {
                if service.entries.isEmpty && searchText.isEmpty {
                    Task {
                        await service.search(query: "")
                    }
                }
            }
        }
    }
}

private struct PhoneBookRow: View {
    let entry: PhoneBookEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.auditory)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let building = entry.buildingAddress {
                    Text(building)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !entry.phones.isEmpty {
                ForEach(entry.phones, id: \.self) { phone in
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
            
            if !entry.departments.isEmpty {
                Text(entry.departments.map { $0.abbrev }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            
            if !entry.employees.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.employees) { employee in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.gray)
                                .font(.body)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(employee.fio)
                                    .font(.subheadline.weight(.medium))
                                
                                if let pos = employee.jobPosition, !pos.isEmpty {
                                    Text(pos)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
