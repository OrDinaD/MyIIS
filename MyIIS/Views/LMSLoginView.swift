import SwiftUI

struct LMSLoginView: View {
    @StateObject private var lmsService = LMSService.shared
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title)
                            .foregroundColor(.blue)

                        Text(NSLocalizedString("services_item_lms", comment: ""))
                            .font(.headline)
                    }

                    Text("СЭО (Система электронного обучения) БГУИР на базе Moodle.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                if lmsService.isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Вы авторизованы")
                        Spacer()
                        Button("Выйти") {
                            lmsService.logout()
                        }
                        .foregroundColor(.red)
                    }

                    Link(destination: URL(string: "https://lms.bsuir.by")!) {
                        HStack {
                            Text("Перейти на сайт СЭО")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Не авторизован")
                    }

                    Button {
                        Task {
                            do {
                                try await lmsService.login()
                            } catch {
                                errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    } label: {
                        if lmsService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Войти используя данные IIS")
                        }
                    }
                    .disabled(lmsService.isLoading)
                }
            } header: {
                Text("Статус")
            } footer: {
                if !lmsService.isLoggedIn {
                    Text("Для входа используются те же данные, что и для личного кабинета ИИС БГУИР.")
                }
            }

            if let message = lmsService.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if lmsService.isLoggedIn && !lmsService.courses.isEmpty {
                Section {
                    ForEach(lmsService.courses) { course in
                        NavigationLink(destination: LMSCourseDetailView(course: course)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.name)
                                    .font(.headline)
                                if !course.teachers.isEmpty {
                                    Text(course.teachersString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Мои курсы")
                }
            }
        }
        .navigationTitle(NSLocalizedString("services_item_lms", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ошибка", isPresented: $showingError) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await lmsService.checkSession()
        }
        .refreshable {
            await lmsService.refreshCourses(force: true)
        }
    }
}

#Preview {
    NavigationStack {
        LMSLoginView()
    }
}
