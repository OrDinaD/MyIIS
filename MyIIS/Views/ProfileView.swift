//
//  ProfileView.swift
//  MyIIS
//
import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showContacts = false
    @State private var showLogoutConfirmation = false
    @State private var showRatingInfo = false
    @State private var showingSettings = false

    // Для полноэкранной аватарки
    @State private var showFullScreenAvatar = false
    @State private var currentZoom: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @Namespace private var avatarNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                if let user = viewModel.user {
                    ScrollView {
                        VStack(spacing: 20) {

                            // MARK: - Header with Photo and Name
                            VStack(spacing: 12) {
                                // Avatar - чистый без размытия
                                AsyncImage(url: user.photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .matchedGeometryEffect(id: "avatar", in: avatarNamespace, isSource: !showFullScreenAvatar)
                                        .frame(width: 132, height: 132)
                                        .clipShape(Circle())
                                        .overlay {
                                            Circle()
                                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                                        }
                                        .contentShape(Circle())
                                        .onLongPressGesture(minimumDuration: 0.3) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                                showFullScreenAvatar = true
                                            }
                                        }
                                        .opacity(showFullScreenAvatar ? 0 : 1)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 132, height: 132)
                                        .overlay {
                                            Text(user.initials)
                                                .font(.system(size: 44, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                                        }
                                }

                                // Name
                                Text(formattedFullName(user))
                                    .font(.title2.weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .minimumScaleFactor(0.92)
                                    .padding(.horizontal, 20)

                                if let belarusianFullName = formattedBelarusianFullName(user) {
                                    Text(belarusianFullName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 20)
                                }

                                // Рейтинг звездочками (если включено)
                                if user.settings.isShowRating {
                                    HStack(spacing: 4) {
                                        ForEach(0..<5) { index in
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(index < user.rating ? Color.yellow : Color.secondary.opacity(0.3))
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onLongPressGesture(minimumDuration: 0.35) {
                                        showRatingInfo = true
                                    }
                                    .alert(NSLocalizedString("profile_rating_alert_title", comment: ""), isPresented: $showRatingInfo) {
                                        Button(NSLocalizedString("profile_rating_alert_button", comment: ""), role: .cancel) {}
                                    } message: {
                                        Text(NSLocalizedString("profile_rating_alert_message", comment: ""))
                                    }
                                }
                            }
                            .padding(.top, 8)

                            // MARK: - Education Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: NSLocalizedString("profile_education_header", comment: ""), icon: "graduationcap.fill")

                                GlassCard {
                                    VStack(spacing: 12) {
                                        InfoRow(label: NSLocalizedString("profile_faculty", comment: ""), value: user.education.faculty)
                                        Divider()
                                        InfoRow(label: NSLocalizedString("profile_speciality", comment: ""), value: user.education.speciality)
                                        Divider()
                                        InfoRow(label: NSLocalizedString("profile_group", comment: ""), value: user.education.group)
                                        Divider()
                                        InfoRow(label: NSLocalizedString("profile_course", comment: ""), value: "\(user.education.course)")
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)

                            // MARK: - Personal Info Section (только если есть данные)
                            if user.birthDay != "Не указана" {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: NSLocalizedString("profile_personal_info_header", comment: ""), icon: "person.fill")

                                    GlassCard {
                                        VStack(spacing: 12) {
                                            // Показываем дату рождения только если она указана
                                            if user.birthDay != "Не указана" {
                                                InfoRow(label: NSLocalizedString("profile_birth_day", comment: ""), value: formatDate(user.birthDay))
                                            }

                                        }
                                        .padding()
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // MARK: - Contacts Section (ниже основной информации)
                            if viewModel.user != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SectionHeader(title: NSLocalizedString("profile_contacts_header", comment: ""), icon: "envelope.fill")
                                        Spacer()
                                        let contactsToggleTitle = showContacts
                                            ? NSLocalizedString("profile_contacts_hide", comment: "")
                                            : NSLocalizedString("profile_contacts_show", comment: "")
                                        Button(contactsToggleTitle) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showContacts.toggle()
                                            }
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .buttonStyle(.plain)
                                    }

                                    if showContacts {
                                        GlassCard {
                                            VStack(spacing: 12) {
                                                if let email = viewModel.user?.email, !email.isEmpty {
                                                    HStack {
                                                        Image(systemName: "envelope.fill")
                                                            .foregroundStyle(Color.accentColor)
                                                            .frame(width: 20)
                                                        Text(email)
                                                            .font(.body)
                                                            .textSelection(.enabled)
                                                        Spacer()
                                                    }
                                                }

                                                if let phone = viewModel.user?.phone, !phone.isEmpty {
                                                    if viewModel.user?.email != nil {
                                                        Divider()
                                                    }
                                                    HStack {
                                                        Image(systemName: "phone.fill")
                                                            .foregroundStyle(Color.accentColor)
                                                            .frame(width: 20)
                                                        Text(phone)
                                                            .font(.body)
                                                            .textSelection(.enabled)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                            .padding()
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // MARK: - Account Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: NSLocalizedString("profile_account_header", comment: ""), icon: "person.crop.circle.badge.checkmark")

                                Button {
                                    showLogoutConfirmation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundStyle(.red)
                                        Text(NSLocalizedString("profile_logout_button", comment: ""))
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                            }
                                    }
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog(
                                    NSLocalizedString("profile_logout_confirmation_title", comment: ""),
                                    isPresented: $showLogoutConfirmation,
                                    titleVisibility: .visible
                                ) {
                                    Button(NSLocalizedString("profile_logout_confirm", comment: ""), role: .destructive) {
                                        withAnimation {
                                            viewModel.logout()
                                        }
                                    }
                                    Button(NSLocalizedString("profile_logout_cancel", comment: ""), role: .cancel) {}
                                } message: {
                                    Text(NSLocalizedString("profile_logout_confirmation_message", comment: ""))
                                }
                            }
                            .padding(.horizontal)

                            Spacer(minLength: 120) // Отступ для парящего таб-бара
                        }
                    }
                    .glassScrollPadding(top: 16)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .navigationDestination(isPresented: $showingSettings) {
                        AccountSettingsView()
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("profile_no_data", comment: ""))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Full Screen Avatar Overlay
                if showFullScreenAvatar, let user = viewModel.user {
                    Color.black.ignoresSafeArea()
                        .opacity(showFullScreenAvatar ? (1.0 - Double(abs(currentOffset.height) / 500)) : 0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                currentZoom = 1.0
                                currentOffset = .zero
                                showFullScreenAvatar = false
                            }
                        }
                    
                    AsyncImage(url: user.photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .matchedGeometryEffect(id: "avatar", in: avatarNamespace, isSource: showFullScreenAvatar)
                            .scaleEffect(currentZoom)
                            .offset(currentOffset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        currentZoom = max(1.0, value)
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            currentZoom = 1.0
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if currentZoom == 1.0 {
                                            currentOffset = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if currentZoom == 1.0 {
                                            if abs(value.translation.height) > 100 {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                                    showFullScreenAvatar = false
                                                    currentOffset = .zero
                                                }
                                            } else {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    currentOffset = .zero
                                                }
                                            }
                                        }
                                    }
                            )
                    } placeholder: {
                        Color.clear
                    }
                    .ignoresSafeArea()
                    .zIndex(100)
                }
            }
            .withBirthdayBalloons(user: viewModel.user)
            .navigationTitle(NSLocalizedString("tab_profile", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .hiddenNavigationBarBackground()
        }
    }

}
