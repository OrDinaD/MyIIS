import SwiftUI

struct UnauthorizedRatingView: View {
    @StateObject private var service = GlobalRatingService.shared

    @State private var selectedFacultyId: Int?
    @State private var selectedSpecialityId: Int?
    @State private var selectedCourse: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("Выбор") {
                    Picker("Факультет", selection: $selectedFacultyId) {
                        Text("Не выбран").tag(Int?.none)
                        ForEach(service.faculties) { faculty in
                            Text(faculty.text).tag(Int?.some(faculty.id))
                        }
                    }
                    .onChange(of: selectedFacultyId) { _, newValue in
                        selectedSpecialityId = nil
                        selectedCourse = nil
                        if let facultyId = newValue {
                            Task { await service.fetchSpecialities(facultyId: facultyId) }
                        } else {
                            service.specialities = []
                            service.courses = []
                            service.ratingEntries = []
                        }
                    }

                    if selectedFacultyId != nil {
                        if service.isLoadingSpecialities {
                            ProgressView("Загрузка специальностей...")
                        } else {
                            Picker("Специальность", selection: $selectedSpecialityId) {
                                Text("Не выбрана").tag(Int?.none)
                                ForEach(service.specialities) { spec in
                                    Text(spec.text).tag(Int?.some(spec.id))
                                }
                            }
                            .onChange(of: selectedSpecialityId) { _, newValue in
                                selectedCourse = nil
                                if let specId = newValue {
                                    Task { await service.fetchCourses(sdefId: specId) }
                                } else {
                                    service.courses = []
                                    service.ratingEntries = []
                                }
                            }
                        }
                    }

                    if selectedSpecialityId != nil {
                        if service.isLoadingCourses {
                            ProgressView("Загрузка курсов...")
                        } else {
                            Picker("Курс", selection: $selectedCourse) {
                                Text("Не выбран").tag(Int?.none)
                                ForEach(service.courses, id: \.self) { course in
                                    Text("\(course) курс").tag(Int?.some(course))
                                }
                            }
                            .onChange(of: selectedCourse) { _, newValue in
                                if let specId = selectedSpecialityId, let course = newValue {
                                    Task { await service.fetchRating(sdefId: specId, course: course) }
                                } else {
                                    service.ratingEntries = []
                                }
                            }
                        }
                    }
                }

                if selectedCourse != nil {
                    Section("Рейтинг") {
                        if service.isLoadingRating {
                            HStack {
                                Spacer()
                                ProgressView("Загрузка рейтинга...")
                                Spacer()
                            }
                        } else if service.ratingEntries.isEmpty {
                            Text("Нет данных")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(service.ratingEntries.enumerated()), id: \.element.id) { index, entry in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .leading)

                                    VStack(alignment: .leading) {
                                        Text("Студ. билет: \(entry.studentCardNumber)")
                                            .font(.body)
                                        if let hours = entry.hours {
                                            Text("Пропусков: \(hours) ч")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }

                                    Spacer()

                                    if let average = entry.average {
                                        Text(String(format: "%.2f", average))
                                            .font(.system(.title3, design: .rounded).weight(.semibold))
                                            .foregroundStyle(average >= 8.0 ? .green : (average >= 6.0 ? .blue : .red))
                                            .monospacedDigit()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Рейтинг группы")
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .hiddenNavigationBarBackground()
            .onAppear {
                if service.faculties.isEmpty {
                    Task { await service.fetchFaculties() }
                }
            }
        }
    }
}
