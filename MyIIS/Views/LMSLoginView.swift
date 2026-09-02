import SwiftUI

struct LMSLoginView: View {
    @StateObject private var lmsService = LMSService.shared
    @State private var username = ""
    @State private var password = ""
    @State private var persistCredentials = false
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

                    Text("СЭО БГУИР на базе Moodle использует отдельную авторизацию.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            if lmsService.isLoggedIn {
                authorizedSection
                coursesSection
            } else {
                credentialsSection
            }

            if let message = lmsService.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(NSLocalizedString("services_item_lms", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ошибка", isPresented: $showingError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            if username.isEmpty {
                username = lmsService.savedUsername()
                persistCredentials = !username.isEmpty
            }
            await lmsService.checkSession()
        }
        .refreshable {
            await lmsService.refreshCourses(force: true)
        }
    }

    private var authorizedSection: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Вы авторизованы")
                Spacer()
                Button("Выйти", role: .destructive) {
                    lmsService.logout()
                    password = ""
                    persistCredentials = false
                }
            }

            Link(destination: NetworkSecurityPolicy.lmsBaseURL) {
                HStack {
                    Text("Перейти на сайт СЭО")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Статус")
        }
    }

    private var credentialsSection: some View {
        Section {
            TextField("Логин СЭО", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Пароль СЭО", text: $password)
                .textContentType(.password)

            Toggle("Сохранить данные СЭО в Keychain", isOn: $persistCredentials)

            Button {
                login()
            } label: {
                HStack {
                    if lmsService.isLoading {
                        ProgressView()
                    }
                    Text("Войти в СЭО")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(
                lmsService.isLoading
                    || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || password.isEmpty
            )
        } header: {
            Text("Отдельные данные СЭО")
        } footer: {
            Text(
                "Пароль СЭО не читается из хранилища ИИС. "
                    + "При включённом переключателе он сохраняется в отдельной записи Keychain."
            )
        }
    }

    @ViewBuilder
    private var coursesSection: some View {
        if !lmsService.courses.isEmpty {
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

    private func login() {
        Task {
            do {
                try await lmsService.login(
                    username: username,
                    password: password,
                    persistCredentials: persistCredentials
                )
                password = ""
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        LMSLoginView()
    }
}
