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

    @State fileprivate var showFullScreenAvatar = false
    @State fileprivate var currentZoom: CGFloat = 1.0
    @State fileprivate var steadyZoom: CGFloat = 1.0
    @State fileprivate var currentOffset: CGSize = .zero
    @State fileprivate var steadyOffset: CGSize = .zero
    @State fileprivate var isPressingAvatar = false
    @Namespace fileprivate var avatarNamespace

    fileprivate let avatarDismissThreshold: CGFloat = 140
    fileprivate let maximumAvatarZoom: CGFloat = 4.0

    var body: some View {
        NavigationStack {
            rootContent
        }
    }
}

private extension ProfileView {
    var rootContent: some View {
        ZStack {
            if let user = viewModel.user {
                profileContent(for: user)
            } else {
                emptyState
            }

            if showFullScreenAvatar, let user = viewModel.user {
                fullScreenAvatar(for: user)
                    .transition(.identity)
                    .zIndex(100)
            }
        }
        .withBirthdayBalloons(user: viewModel.user)
        .navigationTitle(NSLocalizedString("tab_profile", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(showFullScreenAvatar ? .hidden : .visible, for: .navigationBar)
        .toolbar(showFullScreenAvatar ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(showFullScreenAvatar)
        .hiddenNavigationBarBackground()
    }

    func profileContent(for user: User) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader(for: user)
                    .padding(.top, 8)

                educationSection(for: user)
                    .padding(.horizontal)

                if user.birthDay != "Не указана" {
                    personalInfoSection(for: user)
                        .padding(.horizontal)
                }

                if viewModel.user != nil {
                    contactsSection
                        .padding(.horizontal)
                }

                accountSection
                    .padding(.horizontal)

                Spacer(minLength: 120)
            }
        }
        .glassScrollPadding(top: 16)
        .toolbar { profileToolbar }
        .navigationDestination(isPresented: $showingSettings) {
            AccountSettingsView()
        }
        .scrollDisabled(showFullScreenAvatar)
        .allowsHitTesting(!showFullScreenAvatar)
    }

    @ToolbarContentBuilder
    var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.primary)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("profile_no_data", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    func profileHeader(for user: User) -> some View {
        VStack(spacing: 12) {
            avatarThumbnail(for: user)

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

            if user.settings.isShowRating {
                ratingView(for: user)
            }
        }
    }

    @ViewBuilder
    func avatarThumbnail(for user: User) -> some View {
        CachedAsyncImage(url: user.photoURL) { image in
            interactiveAvatarThumbnail {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .matchedGeometryEffect(
                        id: "avatar",
                        in: avatarNamespace,
                        isSource: !showFullScreenAvatar
                    )
            }
        } placeholder: {
            interactiveAvatarThumbnail {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay {
                        Text(user.initials)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
            }
        }
    }

    func interactiveAvatarThumbnail<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: 132, height: 132)
            .clipShape(Circle())
            .overlay { avatarStroke }
            .shadow(
                color: Color.accentColor.opacity(isPressingAvatar ? 0.28 : 0.12),
                radius: isPressingAvatar ? 18 : 8,
                y: isPressingAvatar ? 12 : 6
            )
            .scaleEffect(isPressingAvatar ? 0.94 : 1.0)
            .rotationEffect(.degrees(isPressingAvatar ? -3 : 0))
            .contentShape(Circle())
            .onLongPressGesture(
                minimumDuration: 0.28,
                maximumDistance: 24,
                pressing: avatarPressing,
                perform: presentFullScreenAvatar
            )
            .opacity(showFullScreenAvatar ? 0 : 1)
    }

    var avatarStroke: some View {
        Circle()
            .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
    }

    func avatarPressing(_ isPressing: Bool) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.6)) {
            isPressingAvatar = isPressing
        }
    }

    func ratingView(for user: User) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                Image(systemName: "star.fill")
                    .foregroundStyle(
                        index < user.rating ? Color.yellow : Color.secondary.opacity(0.3)
                    )
                    .font(.system(size: 14))
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.35) {
            showRatingInfo = true
        }
        .alert(
            NSLocalizedString("profile_rating_alert_title", comment: ""),
            isPresented: $showRatingInfo
        ) {
            Button(
                NSLocalizedString("profile_rating_alert_button", comment: ""),
                role: .cancel
            ) {}
        } message: {
            Text(NSLocalizedString("profile_rating_alert_message", comment: ""))
        }
    }

    func educationSection(for user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: NSLocalizedString("profile_education_header", comment: ""),
                icon: "graduationcap.fill"
            )

            GlassCard {
                VStack(spacing: 12) {
                    InfoRow(
                        label: NSLocalizedString("profile_faculty", comment: ""),
                        value: user.education.faculty
                    )
                    Divider()
                    InfoRow(
                        label: NSLocalizedString("profile_speciality", comment: ""),
                        value: user.education.speciality
                    )
                    Divider()
                    InfoRow(
                        label: NSLocalizedString("profile_group", comment: ""),
                        value: user.education.group
                    )
                    Divider()
                    InfoRow(
                        label: NSLocalizedString("profile_course", comment: ""),
                        value: "\(user.education.course)"
                    )
                }
                .padding()
            }
        }
    }

    func personalInfoSection(for user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: NSLocalizedString("profile_personal_info_header", comment: ""),
                icon: "person.fill"
            )

            GlassCard {
                VStack(spacing: 12) {
                    InfoRow(
                        label: NSLocalizedString("profile_birth_day", comment: ""),
                        value: formatDate(user.birthDay)
                    )
                }
                .padding()
            }
        }
    }

    var contactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(
                    title: NSLocalizedString("profile_contacts_header", comment: ""),
                    icon: "envelope.fill"
                )
                Spacer()
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
                            contactRow(systemImage: "envelope.fill", value: email)
                        }

                        if let phone = viewModel.user?.phone, !phone.isEmpty {
                            if viewModel.user?.email != nil {
                                Divider()
                            }
                            contactRow(systemImage: "phone.fill", value: phone)
                        }
                    }
                    .padding()
                }
                .transition(
                    .asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    )
                )
            }
        }
    }

    var contactsToggleTitle: String {
        showContacts
            ? NSLocalizedString("profile_contacts_hide", comment: "")
            : NSLocalizedString("profile_contacts_show", comment: "")
    }

    func contactRow(systemImage: String, value: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
            Spacer()
        }
    }

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: NSLocalizedString("profile_account_header", comment: ""),
                icon: "person.crop.circle.badge.checkmark"
            )

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
                Button(
                    NSLocalizedString("profile_logout_confirm", comment: ""),
                    role: .destructive
                ) {
                    withAnimation {
                        viewModel.logout()
                    }
                }
                Button(
                    NSLocalizedString("profile_logout_cancel", comment: ""),
                    role: .cancel
                ) {}
            } message: {
                Text(
                    NSLocalizedString(
                        "profile_logout_confirmation_message",
                        comment: ""
                    )
                )
            }
        }
    }

    @ViewBuilder
    func fullScreenAvatar(for user: User) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(fullScreenBackgroundOpacity)
                .onTapGesture {
                    dismissFullScreenAvatar()
                }

            CachedAsyncImage(url: user.photoURL) { image in
                fullScreenAvatarContent {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            } placeholder: {
                fullScreenAvatarContent {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay {
                            Text(user.initials)
                                .font(.system(size: 72, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                }
            }
        }
        .ignoresSafeArea()
    }

    func fullScreenAvatarContent<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .matchedGeometryEffect(
                id: "avatar",
                in: avatarNamespace,
                properties: .frame,
                anchor: .center,
                isSource: showFullScreenAvatar
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: fullScreenCornerRadius,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.28), radius: 24, y: 14)
            .scaleEffect(currentZoom)
            .offset(currentOffset)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(fullScreenMagnificationGesture)
            .simultaneousGesture(fullScreenDragGesture)
    }

    var fullScreenMagnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let nextZoom = steadyZoom * value.magnification
                currentZoom = min(max(nextZoom, 1.0), maximumAvatarZoom)
            }
            .onEnded { _ in
                let clampedZoom = min(max(currentZoom, 1.0), maximumAvatarZoom)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    currentZoom = clampedZoom
                    steadyZoom = clampedZoom
                    if clampedZoom <= 1.02 {
                        steadyZoom = 1.0
                        currentZoom = 1.0
                        steadyOffset = .zero
                        currentOffset = .zero
                    } else {
                        let clampedOffset = clampedOffset(for: currentOffset, zoom: clampedZoom)
                        steadyOffset = clampedOffset
                        currentOffset = clampedOffset
                    }
                }
            }
    }

    var fullScreenDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if currentZoom > 1.02 {
                    currentOffset = clampedOffset(
                        for: CGSize(
                            width: steadyOffset.width + value.translation.width,
                            height: steadyOffset.height + value.translation.height
                        ),
                        zoom: currentZoom
                    )
                } else {
                    currentOffset = CGSize(
                        width: value.translation.width * 0.18,
                        height: value.translation.height
                    )
                }
            }
            .onEnded { value in
                if currentZoom > 1.02 {
                    let clampedOffset = clampedOffset(for: currentOffset, zoom: currentZoom)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        currentOffset = clampedOffset
                        steadyOffset = clampedOffset
                    }
                    return
                }

                let projectedDismissHeight = max(
                    abs(value.translation.height),
                    abs(value.predictedEndTranslation.height)
                )
                if projectedDismissHeight > avatarDismissThreshold {
                    dismissFullScreenAvatar(initialVelocity: value.velocity.height)
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        currentOffset = .zero
                        steadyOffset = .zero
                    }
                }
            }
    }

    var fullScreenBackgroundOpacity: Double {
        let dragProgress = min(abs(currentOffset.height) / 260, 1)
        let zoomBoost = min((currentZoom - 1) / 2.0, 0.12)
        return max(0.32, 1.0 - Double(dragProgress) * 0.58 + Double(zoomBoost))
    }

    var fullScreenCornerRadius: CGFloat {
        guard currentZoom <= 1.02 else { return 20 }
        let dragProgress = min(abs(currentOffset.height) / 220, 1)
        return 18 + (dragProgress * 18)
    }

    func presentFullScreenAvatar() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.95)
        resetAvatarInteractionState()
        withAnimation(.spring(response: 0.52, dampingFraction: 0.82, blendDuration: 0.16)) {
            isPressingAvatar = false
            showFullScreenAvatar = true
        }
    }

    func dismissFullScreenAvatar(initialVelocity: CGFloat = 0) {
        let normalizedVelocity = min(max(abs(initialVelocity) / 1800, 0), 1)
        withAnimation(
            .spring(
                response: 0.46,
                dampingFraction: 0.78 - (normalizedVelocity * 0.12),
                blendDuration: 0.14
            )
        ) {
            resetAvatarInteractionState()
            showFullScreenAvatar = false
        }
    }

    func resetAvatarInteractionState() {
        currentZoom = 1.0
        steadyZoom = 1.0
        currentOffset = .zero
        steadyOffset = .zero
        isPressingAvatar = false
    }

    func clampedOffset(for offset: CGSize, zoom: CGFloat) -> CGSize {
        guard zoom > 1.02 else { return .zero }

        let horizontalLimit = 48 * (zoom - 1)
        let verticalLimit = 88 * (zoom - 1)

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }
}
