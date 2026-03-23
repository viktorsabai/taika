# Firebase setup (Auth + Firestore)

1. Create a project in [Firebase Console](https://console.firebase.google.com/).
2. Add an iOS app with Bundle ID: `com.sabishev.taika`.
3. Download **GoogleService-Info.plist** and add it to the **taika** target (drag into Xcode → taika group, ensure "Copy items if needed" and taika target are checked).
4. In Firebase Console enable:
   - **Authentication** → Sign-in method → **Apple** (enable).
   - **Firestore Database** → Create database (start in test mode or set rules; for production use `users/{userId}` read/write for `request.auth != null`).
5. In Apple Developer: App ID → Capabilities → **Sign in with Apple** (already added in taika.entitlements).

Without GoogleService-Info.plist the app runs with local-only progress; Sign in with Apple and cloud sync are no-ops until Firebase is configured.
