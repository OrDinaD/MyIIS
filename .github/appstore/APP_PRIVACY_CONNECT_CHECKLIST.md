# App Store Connect: App Privacy Checklist (MyIIS)

Last reviewed: 2026-06-11

This checklist maps current repository behavior to App Privacy answers in App Store Connect.
Use it together with Xcode's generated privacy report before submitting a new App Store version.

## 1) Tracking

- `Data Used to Track You`: **No**
- `NSPrivacyTracking`: `false`

## 2) Data Collection (conservative declaration)

Mark **Collected** for the following data types and set purpose to **App Functionality**:

1. `Name`
2. `Email Address`
3. `Phone Number`
4. `User ID` (student account identifier)
5. `Photos or Videos` (profile photo upload flow)

For each item above:

1. `Linked to User`: **Yes**
2. `Used for Tracking`: **No**

## 3) Data Not Collected (set to No unless behavior changes)

1. Health & Fitness
2. Financial Info
3. Precise Location
4. Sensitive Info
5. Contacts from address book
6. Browsing/Search history
7. Purchases
8. Diagnostics for third-party analytics/ads

## 4) Required Reason API usage

Current manifest reasons declared:

1. App: `PrivacyInfo.xcprivacy`
2. Widget: `MyIISWidget/PrivacyInfo.xcprivacy`
3. Intents extension: `MyIISIntents/PrivacyInfo.xcprivacy`

All of them currently declare:

1. `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`

Current scan did not find tracking domains, analytics SDKs, advertising SDKs, or additional required-reason API categories in app code. Temporary-file writes are used for user-initiated exports/previews; no file timestamp, system boot time, disk space, or active keyboard API usage is currently declared or expected.

If new APIs from Apple's Required Reason API list are added, update the matching target's `PrivacyInfo.xcprivacy` in the same PR.

## 5) Evidence in codebase

1. Auth/profile/contact data requests: `MyIIS/Services/APIService.swift`, `MyIIS/Services/AccountSettingsService.swift`
2. Profile photo upload flow: `MyIIS/ViewModels/AccountSettingsViewModel.swift`
3. Camera/photo permissions: `MyIIS.xcodeproj/project.pbxproj` (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`)
4. User defaults + app group state: `Shared/MyIISDataStore.swift`, `Shared/AttendanceWidgetDataStore.swift`
5. Privacy policy and terms are linked from `MyIIS/Views/AboutAppView.swift`.

## 6) Release gate before submission

1. Re-open App Privacy screen in App Store Connect and verify all toggles match this file.
2. Confirm `PrivacyInfo.xcprivacy` included in release archive.
3. Confirm no analytics/ads SDKs were added since last review.
4. Generate Xcode's privacy report from the signed archive and compare it with this checklist.
5. Confirm App Store Connect review metadata includes reviewer contact details and a working demo account or clear demo instructions.
