import SwiftUI
import SafariServices

struct SupportView: View {
    @StateObject private var viewModel = SupportViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("Режим", selection: $selectedTab) {
                Text("Форма заявки").tag(0)
                Text("Документы").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                SupportFormView(viewModel: viewModel)
            } else {
                SupportDocumentsView()
            }
        }
        .navigationTitle("Техническая поддержка")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SupportFormView: View {
    @ObservedObject var viewModel: SupportViewModel
    @State private var showingAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Контактные данные")) {
                TextField("ФИО (обязательно)", text: $viewModel.fioString)
                TextField("Email (обязательно)", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            Section(header: Text("Категория проблемы")) {
                if viewModel.isLoadingCategories {
                    ProgressView()
                } else if let error = viewModel.categoryError {
                    Text(error).foregroundColor(.red)
                    Button("Повторить") {
                        Task { await viewModel.loadCategories() }
                    }
                } else {
                    Picker("Категория", selection: $viewModel.selectedCategory) {
                        Text("Выберите...").tag(BugReportCategoryDTO?.none)
                        ForEach(viewModel.categories) { cat in
                            Text(cat.categoryName).tag(BugReportCategoryDTO?.some(cat))
                        }
                    }
                }
            }
            
            if let category = viewModel.selectedCategory {
                if let subcategories = category.bugReportSubcategoriesDto, subcategories.count > 1 {
                    Section(header: Text("Подкатегория")) {
                        Picker("Подкатегория", selection: $viewModel.selectedSubcategory) {
                            Text("Выберите...").tag(BugReportSubcategoryDTO?.none)
                            ForEach(subcategories) { sub in
                                Text(sub.subcategoryName).tag(BugReportSubcategoryDTO?.some(sub))
                            }
                        }
                    }
                }
                
                let notices = SupportConfiguration.getNotices(for: category.categoryKey)
                if !notices.isEmpty {
                    Section {
                        ForEach(notices, id: \.self) { notice in
                            HStack {
                                Image(systemName: "info.circle").foregroundColor(.blue)
                                Text(notice).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Детали заявки")) {
                    ForEach(Array(viewModel.formFields.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { field in
                        if field != .acts {
                            let binding = Binding<String>(
                                get: { viewModel.formFields[field] ?? "" },
                                set: { viewModel.formFields[field] = $0 }
                            )
                            if field == .description {
                                TextEditor(text: binding)
                                    .frame(height: 100)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                            } else {
                                TextField(field.rawValue.capitalized, text: binding)
                            }
                        }
                    }
                }
                
                if category.categoryKey == "[ActEquip]" {
                    Section(header: Text("Акты о непригодности")) {
                        ForEach($viewModel.equipmentActs) { $act in
                            VStack(alignment: .leading) {
                                TextField("Тип оборудования", text: $act.equipmentType)
                                TextField("Инвентарный номер", text: $act.inventoryNumber)
                                TextField("Год", text: $act.year).keyboardType(.numberPad)
                            }
                        }
                        Button("Добавить акт") {
                            viewModel.addEquipmentAct()
                        }
                    }
                }
                
                Section {
                    if viewModel.isSubmitting {
                        ProgressView("Отправка...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Button("Отправить") {
                            Task { await viewModel.submit() }
                        }
                        .disabled(viewModel.fioString.isEmpty || viewModel.email.isEmpty || viewModel.selectedCategory == nil)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .task {
            if viewModel.categories.isEmpty {
                await viewModel.loadCategories()
            }
        }
        .alert(isPresented: .init(
            get: { viewModel.submitSuccess || viewModel.submitError != nil },
            set: { _ in viewModel.submitSuccess = false; viewModel.submitError = nil }
        )) {
            if viewModel.submitSuccess {
                return Alert(title: Text("Успех"), message: Text("Заявка успешно отправлена."), dismissButton: .default(Text("OK")))
            } else {
                return Alert(title: Text("Ошибка"), message: Text(viewModel.submitError ?? "Неизвестная ошибка"), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct SupportDocumentsView: View {
    var body: some View {
        List {
            ForEach(SupportConfiguration.documentGroups) { group in
                Section(header: Text(group.groupName)) {
                    if let note = group.note {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    ForEach(group.items) { item in
                        Link(destination: item.url) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(item.title).font(.body).foregroundColor(.primary)
                                    Text(item.number).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
