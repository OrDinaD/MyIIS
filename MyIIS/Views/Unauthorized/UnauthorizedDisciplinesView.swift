import SwiftUI

struct UnauthorizedDisciplinesView: View {
    @StateObject private var service = DisciplinesService.shared
    @StateObject private var formService = GlobalRatingService.shared // Reuse for faculty picking
    
    @State private var selectedFacultyId: Int?
    @State private var selectedSpecialityId: Int?
    @State private var selectedCourse: Int?
    @State private var selectedTerm: Int? // 1, 2, ... based on course?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Выбор") {
                    Picker("Факультет", selection: $selectedFacultyId) {
                        Text("Не выбран").tag(Int?.none)
                        ForEach(formService.faculties) { faculty in
                            Text(faculty.text).tag(Int?.some(faculty.id))
                        }
                    }
                    .onChange(of: selectedFacultyId) { _, newValue in
                        selectedSpecialityId = nil
                        selectedCourse = nil
                        selectedTerm = nil
                        if let facultyId = newValue {
                            Task { await formService.fetchSpecialities(facultyId: facultyId) }
                        } else {
                            formService.specialities = []
                            formService.courses = []
                            service.disciplines = []
                        }
                    }
                    
                    if selectedFacultyId != nil {
                        if formService.isLoadingSpecialities {
                            ProgressView("Загрузка специальностей...")
                        } else {
                            Picker("Специальность", selection: $selectedSpecialityId) {
                                Text("Не выбрана").tag(Int?.none)
                                ForEach(formService.specialities) { spec in
                                    Text(spec.text).tag(Int?.some(spec.id))
                                }
                            }
                            .onChange(of: selectedSpecialityId) { _, newValue in
                                selectedCourse = nil
                                selectedTerm = nil
                                if let specId = newValue {
                                    Task { await formService.fetchCourses(sdefId: specId) }
                                } else {
                                    formService.courses = []
                                    service.disciplines = []
                                }
                            }
                        }
                    }
                    
                    if selectedSpecialityId != nil {
                        if formService.isLoadingCourses {
                            ProgressView("Загрузка курсов...")
                        } else {
                            Picker("Курс", selection: $selectedCourse) {
                                Text("Не выбран").tag(Int?.none)
                                ForEach(formService.courses, id: \.self) { course in
                                    Text("\(course) курс").tag(Int?.some(course))
                                }
                            }
                            .onChange(of: selectedCourse) { _, newValue in
                                selectedTerm = nil
                                fetchDisciplines()
                            }
                        }
                    }
                    
                    if let course = selectedCourse {
                        Picker("Семестр", selection: $selectedTerm) {
                            Text("Весь год").tag(Int?.none)
                            Text("Семестр \(course * 2 - 1)").tag(Int?.some(course * 2 - 1))
                            Text("Семестр \(course * 2)").tag(Int?.some(course * 2))
                        }
                        .onChange(of: selectedTerm) { _, _ in
                            fetchDisciplines()
                        }
                    }
                }
                
                if selectedCourse != nil {
                    Section("Дисциплины") {
                        if service.isLoading {
                            HStack {
                                Spacer()
                                ProgressView("Загрузка...")
                                Spacer()
                            }
                        } else if service.disciplines.isEmpty {
                            Text("Нет данных")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(service.disciplines) { discipline in
                                HStack {
                                    Text(discipline.name)
                                        .font(.body)
                                    Spacer()
                                    if let hours = discipline.hours {
                                        Text("\(hours) ч")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Список дисциплин")
            .onAppear {
                if formService.faculties.isEmpty {
                    Task { await formService.fetchFaculties() }
                }
            }
        }
    }
    
    private func fetchDisciplines() {
        if let specId = selectedSpecialityId, let course = selectedCourse {
            Task { await service.fetchDisciplines(sdefId: specId, course: course, term: selectedTerm) }
        } else {
            service.disciplines = []
        }
    }
}
