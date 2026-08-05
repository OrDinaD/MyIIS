//
//  AccountSettingsView.swift
//  MyIIS
//
import PhotosUI
import SwiftUI
import UIKit

private struct ContactSectionConfig {
    let title: String
    let value: Binding<String>
    let isConfirmed: Bool
    let attempts: Int
    let keyboardType: UIKeyboardType
    let onUpdate: () -> Void
}

private struct PasswordRequirementState: Identifiable {
    let id: String
    let title: String
    let isSatisfied: Bool
}

struct AccountSettingsView: View {
    @State private var viewModel = AccountSettingsViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImageSourceDialog = false
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var tempImage: UIImage?
    @State private var desktopSelection: AccountSettingsTab?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var canUseCameraSource: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
            && !ProcessInfo.processInfo.isiOSAppOnMac
    }

    private var shouldUseDesktopSplitView: Bool {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return false
        }
        return horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldUseDesktopSplitView {
                desktopSplitView
            } else {
                mobileForm
            }
        }
        .appBackground()
        .navigationTitle(NSLocalizedString("settings_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .reduceMotionSensitive()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.selectedTab)
        .alert(item: $viewModel.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text(NSLocalizedString("common_ok", comment: ""))))
        }
        .sheet(isPresented: $viewModel.isConfirmSheetPresented) {
            confirmationSheet
                .presentationDetents([.medium])
        }
        .task {
            await viewModel.load()
            desktopSelection = desktopSelection ?? viewModel.selectedTab
        }
        .onChange(of: desktopSelection) { _, newValue in
            guard let newValue, newValue != viewModel.selectedTab else { return }
            viewModel.selectedTab = newValue
        }
        .onChange(of: viewModel.selectedTab) { _, newValue in
            guard desktopSelection != newValue else { return }
            desktopSelection = newValue
        }
    }

    private var mobileForm: some View {
        Form {
            Section {
                Picker(NSLocalizedString("settings_title", comment: ""), selection: $viewModel.selectedTab) {
                    ForEach(AccountSettingsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(NSLocalizedString("settings_title", comment: ""))
            }

            tabContent
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
    }

    private var desktopSplitView: some View {
        NavigationSplitView {
            List(selection: $desktopSelection) {
                ForEach(AccountSettingsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(Optional(tab))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("settings_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            Form {
                tabContent
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .navigationTitle(viewModel.selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
            .hiddenNavigationBarBackground()
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .password:
            passwordContent
        case .contacts:
            contactsContent
        case .photo:
            photoContent
        }
    }

    private var passwordContent: some View {
        Group {
            Section(NSLocalizedString("settings_password_requirements_header", comment: "")) {
                ForEach(passwordRequirements) { item in
                    requirement(item)
                }
            }

            Section {
                SecureField(NSLocalizedString("settings_password_old_placeholder", comment: ""), text: $viewModel.oldPassword)
                    .textContentType(.password)
                SecureField(NSLocalizedString("settings_password_new_placeholder", comment: ""), text: $viewModel.newPassword)
                    .textContentType(.newPassword)
                SecureField(NSLocalizedString("settings_password_confirm_placeholder", comment: ""), text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
            }

            Section {
                Text(
                    String(
                        format: NSLocalizedString("settings_password_attempts", comment: ""),
                        Int64(viewModel.passwordAttemptsLeft)
                    )
                )

                Text(String(format: NSLocalizedString("settings_password_last_change", comment: ""), viewModel.lastPasswordChangeDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let ban = viewModel.passwordBanExpiredTime {
                    Text(String(format: NSLocalizedString("settings_password_ban", comment: ""), ban))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button {
                    Task { await viewModel.changePassword() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isChangingPassword {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text(
                            viewModel.isChangingPassword
                                ? NSLocalizedString("settings_password_saving", comment: "")
                                : NSLocalizedString("settings_password_submit", comment: "")
                        )
                        .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(viewModel.isChangingPassword)
            }
        }
    }

    private var contactsContent: some View {
        Group {
            contactSection(
                config: ContactSectionConfig(
                    title: NSLocalizedString("settings_contacts_phone_label", comment: ""),
                    value: $viewModel.phoneValue,
                    isConfirmed: viewModel.phoneConfirmed,
                    attempts: viewModel.mobileAttempts,
                    keyboardType: .phonePad,
                    onUpdate: {
                        Task { await viewModel.updateContact(type: .mobilePhone, value: viewModel.phoneValue) }
                    }
                )
            )

            contactSection(
                config: ContactSectionConfig(
                    title: NSLocalizedString("settings_contacts_email_label", comment: ""),
                    value: $viewModel.emailValue,
                    isConfirmed: viewModel.emailConfirmed,
                    attempts: viewModel.emailAttempts,
                    keyboardType: .emailAddress,
                    onUpdate: {
                        Task { await viewModel.updateContact(type: .email, value: viewModel.emailValue) }
                    }
                )
            )

            if let ban = viewModel.contactBanExpiredTime {
                Section {
                    Text(String(format: NSLocalizedString("settings_contacts_ban", comment: ""), ban))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var photoContent: some View {
        Section {
            VStack(spacing: 18) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let photo = viewModel.photoImage {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                        } else if let url = viewModel.photoURL {
                            CachedAsyncImage(url: url, maxPixelSize: 360) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(24)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(24)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 176, height: 176)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1))

                    Button {
                        showingImageSourceDialog = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .padding(10)
                            .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    }
                    .confirmationDialog(NSLocalizedString("settings_photo_change_button", comment: ""), isPresented: $showingImageSourceDialog) {
                        if canUseCameraSource {
                            Button(NSLocalizedString("settings_photo_source_camera", comment: "")) {
                                showingCamera = true
                            }
                        }
                        Button(NSLocalizedString("settings_photo_source_library", comment: "")) {
                            showingPhotosPicker = true
                        }
                        Button(NSLocalizedString("common_cancel", comment: ""), role: .cancel) {}
                    }
                    .photosPicker(
                        isPresented: $showingPhotosPicker,
                        selection: $selectedPhotoItem,
                        matching: .images
                    )
                    .fullScreenCover(isPresented: $showingCamera) {
                        if canUseCameraSource {
                            ImagePicker(selectedImage: $tempImage, sourceType: .camera)
                                .ignoresSafeArea()
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newValue in
                        guard let newValue else { return }
                        Task {
                            do {
                                guard let data = try await newValue.loadTransferable(type: Data.self) else {
                                    viewModel.showError("Ошибка", "Не удалось прочитать выбранное фото.")
                                    selectedPhotoItem = nil
                                    return
                                }

                                await viewModel.updatePhoto(from: data)
                            } catch {
                                viewModel.showError("Ошибка", error.localizedDescription)
                            }
                            selectedPhotoItem = nil
                        }
                    }
                    .onChange(of: tempImage) { _, newValue in
                        guard let newValue, let data = newValue.jpegData(compressionQuality: 0.8) else { return }
                        Task {
                            await viewModel.updatePhoto(from: data)
                            tempImage = nil
                        }
                    }
                }

                if viewModel.isUploadingPhoto {
                    ProgressView(NSLocalizedString("settings_photo_uploading", comment: ""))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
}

private extension AccountSettingsView {
    var confirmationSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("settings_confirm_title", comment: ""))
                .font(.headline)

            if !viewModel.confirmationTargetDescription.isEmpty {
                Text(String(format: NSLocalizedString("settings_confirm_code_sent", comment: ""), viewModel.confirmationTargetDescription))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField(NSLocalizedString("settings_confirm_code_placeholder", comment: ""), text: $viewModel.confirmationCode)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button(NSLocalizedString("settings_confirm_resend", comment: "")) {
                    Task { await viewModel.resendCode() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSendingCode)

                Button(NSLocalizedString("settings_password_submit", comment: "")) {
                    Task { await viewModel.confirmPendingContact() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isConfirmingCode)
            }
        }
        .padding(20)
    }

    var passwordRequirements: [PasswordRequirementState] {
        let newPassword = viewModel.newPassword
        let oldPassword = viewModel.oldPassword

        let hasValidLength = (8 ... 30).contains(newPassword.count)
        let hasLowercaseLatin = newPassword.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercaseLatin = newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = newPassword.range(of: "\\d", options: .regularExpression) != nil
        let hasSpecialSymbol = newPassword.range(of: "[!-/:-@\\[-`\\{-~]", options: .regularExpression) != nil
        let differsFromOld = !newPassword.isEmpty && (oldPassword.isEmpty || newPassword != oldPassword)

        return [
            PasswordRequirementState(
                id: "length",
                title: NSLocalizedString("settings_password_req_length", comment: ""),
                isSatisfied: hasValidLength
            ),
            PasswordRequirementState(
                id: "cases",
                title: NSLocalizedString("settings_password_req_cases", comment: ""),
                isSatisfied: hasLowercaseLatin && hasUppercaseLatin
            ),
            PasswordRequirementState(
                id: "digits",
                title: NSLocalizedString("settings_password_req_digits", comment: ""),
                isSatisfied: hasDigit
            ),
            PasswordRequirementState(
                id: "special",
                title: NSLocalizedString("settings_password_req_special", comment: ""),
                isSatisfied: hasSpecialSymbol
            ),
            PasswordRequirementState(
                id: "different",
                title: NSLocalizedString("settings_password_req_diff", comment: ""),
                isSatisfied: differsFromOld
            )
        ]
    }

    func requirement(_ item: PasswordRequirementState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isSatisfied ? .green : .secondary)
                .font(.callout)

            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(item.isSatisfied ? .green : .primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(item.isSatisfied ? Color.green.opacity(0.12) : Color.clear)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: item.isSatisfied)
        .accessibilityTextPair(label: item.title, value: item.isSatisfied ? "Выполнено" : "Не выполнено")
    }

    func contactSection(config: ContactSectionConfig) -> some View {
        Section(config.title) {
            Label(
                config.isConfirmed
                    ? NSLocalizedString("settings_contacts_confirmed", comment: "")
                    : NSLocalizedString("settings_contacts_not_confirmed", comment: ""),
                systemImage: config.isConfirmed ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(config.isConfirmed ? .green : .orange)

            TextField(NSLocalizedString("settings_contacts_value_placeholder", comment: ""), text: config.value)
                .keyboardType(config.keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(!viewModel.canEditContacts)

            Text(
                String(
                    format: NSLocalizedString("settings_password_attempts", comment: ""),
                    Int64(config.attempts)
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Button(NSLocalizedString("settings_contacts_update_button", comment: "")) {
                config.onUpdate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canEditContacts || viewModel.isUpdatingContact)
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
    }
}
