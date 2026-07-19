import Foundation
import Combine

@MainActor
class SupportViewModel: ObservableObject {
    @Published var categories: [BugReportCategoryDTO] = []
    @Published var isLoadingCategories = false
    @Published var categoryError: String?
    
    @Published var selectedCategory: BugReportCategoryDTO?
    @Published var selectedSubcategory: BugReportSubcategoryDTO?
    
    @Published var formFields: [SupportField: String] = [:]
    @Published var equipmentActs: [EquipmentAct] = []
    @Published var attachments: [SupportAttachment] = []
    
    @Published var lastName = ""
    @Published var firstName = ""
    @Published var middleName = ""
    @Published var fioString = ""
    @Published var email = ""
    
    @Published var isSubmitting = false
    @Published var submitSuccess = false
    @Published var submitError: String?
    
    // Autocomplete
    @Published var departmentSuggestions: [DepartmentFilterResponse] = []
    @Published var auditorySuggestions: [AuditoryFilterResponse] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let service = SupportService.shared
    
    init() {
        $fioString
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.parseFIO(newValue)
                Task { [weak self] in
                    await self?.tryAutocompleteByPersonalInfo()
                }
            }
            .store(in: &cancellables)
            
        $email
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.tryAutocompleteByPersonalInfo()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadCategories() async {
        isLoadingCategories = true
        categoryError = nil
        do {
            categories = try await service.getCategories()
        } catch {
            categoryError = "Ошибка загрузки категорий"
        }
        isLoadingCategories = false
    }
    
    func selectCategory(_ category: BugReportCategoryDTO) {
        selectedCategory = category
        selectedSubcategory = nil
        let newFields = SupportConfiguration.getFields(for: category.categoryKey)
        
        // Retain existing values if fields overlap, clear otherwise
        var newFormFields: [SupportField: String] = [:]
        for field in newFields {
            newFormFields[field] = formFields[field] ?? ""
        }
        formFields = newFormFields
        
        if category.categoryKey == "[ActEquip]" && equipmentActs.isEmpty {
            equipmentActs.append(EquipmentAct())
        }
    }
    
    func addAttachment(_ attachment: SupportAttachment) {
        let totalSize = attachments.reduce(0) { $0 + $1.data.count } + attachment.data.count
        if totalSize <= 52_428_800 {
            attachments.append(attachment)
        } else {
            submitError = "Превышен максимальный размер вложений (50 МБ)"
        }
    }
    
    func removeAttachment(at index: Int) {
        attachments.remove(at: index)
    }
    
    func removeEquipmentAct(at index: Int) {
        equipmentActs.remove(at: index)
    }
    
    func addEquipmentAct() {
        equipmentActs.append(EquipmentAct())
    }
    
    private func parseFIO(_ rawFio: String) {
        let trimmed = rawFio.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let parts = trimmed.split(separator: " ").map(String.init)
        
        if parts.count >= 3 && trimmed.contains(".") {
            lastName = trimmed
            firstName = ""
            middleName = ""
        } else {
            lastName = parts.isEmpty ? "" : parts[0]
            firstName = parts.count > 1 ? parts[1] : ""
            middleName = parts.count > 2 ? parts[2...].joined(separator: " ") : ""
        }
    }
    
    private func tryAutocompleteByPersonalInfo() async {
        guard !fioString.isEmpty && !email.isEmpty else { return }
        
        do {
            let req = AutocompletePersonalInfoRequest(fio: fioString, email: email)
            let res = try await service.autocompleteByPersonalInfo(request: req)
            if let p = res.phone, (formFields[.phone] == nil || formFields[.phone]!.isEmpty) {
                formFields[.phone] = p
            }
        } catch {
            print("Autocomplete failed: \(error)")
        }
    }
    
    func searchDepartments(query: String) async {
        guard query.count > 2 else { return }
        do {
            departmentSuggestions = try await service.searchDepartments(query: query)
        } catch {
            print("Dept search error: \(error)")
        }
    }
    
    func searchAuditories(query: String) async {
        guard query.count > 2 else { return }
        do {
            auditorySuggestions = try await service.searchAuditories(query: query)
        } catch {
            print("Auditory search error: \(error)")
        }
    }
    
    func submit() async {
        guard let category = selectedCategory else { return }
        isSubmitting = true
        submitError = nil
        
        do {
            var params: [String: String] = [
                "lastName": lastName,
                "firstName": firstName,
                "middleName": middleName,
                "email": email
            ]
            
            if let subcategory = selectedSubcategory {
                params["subject"] = "\(subcategory.subcategoryKey) \(subcategory.subcategoryName)"
                params["subcategoryId"] = "\(subcategory.id)"
            } else {
                params["subject"] = "\(category.categoryKey) \(category.categoryName)"
            }
            
            params["categoryId"] = "\(category.id)"
            params["browser"] = "MyIIS iOS App"
            params["labels"] = ""
            
            for (field, value) in formFields {
                params[field.rawValue] = value
            }
            
            if category.categoryKey == "[ActEquip]" {
                var actsForSend = equipmentActs
                for i in 0..<actsForSend.count {
                    actsForSend[i].key = i + 1
                }
                let actsData = try JSONEncoder().encode(actsForSend)
                if let actsString = String(data: actsData, encoding: .utf8) {
                    params["acts"] = actsString
                }
            }
            
            try await service.submitBugReport(parameters: params, files: attachments)
            submitSuccess = true
        } catch {
            submitError = "Не удалось отправить заявку."
        }
        isSubmitting = false
    }
}
