//
//  AuthService.swift
//  taika
//
//  Sign in with Apple via Firebase Auth. No-op when Firebase is not configured.
//

import Foundation
import UIKit
import AuthenticationServices
import FirebaseAuth
import FirebaseCore

/// Holds presentation window for Sign in with Apple (nonisolated so delegate can read it).
private enum AuthServicePresentation {
    static var window: UIWindow?
}

@MainActor
public final class AuthService: NSObject, ObservableObject {

    public static let shared = AuthService()

    private static let displayNameKey = "authService.displayName"

    @Published public private(set) var currentUserID: String?
    @Published public private(set) var isLoggedIn: Bool = false
    @Published public private(set) var authError: String?
    /// Имя из Apple ID (сохраняется при первом входе; Apple отдаёт fullName только один раз).
    @Published public private(set) var displayName: String?

    /// Set from UI before signInWithApple() so the sheet has a window. Use AuthServicePresentation.window (nonisolated).
    public static var presentationWindow: UIWindow? {
        get { AuthServicePresentation.window }
        set { AuthServicePresentation.window = newValue }
    }

    private var continuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
        if FirebaseApp.app() != nil {
            updateState()
            _ = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
                Task { @MainActor in
                    self?.updateState()
                }
            }
        }
    }

    private func updateState() {
        let user = Auth.auth().currentUser
        let previousID = currentUserID
        currentUserID = user?.uid
        isLoggedIn = user != nil
        if user != nil {
            if displayName == nil {
                displayName = UserDefaults.standard.string(forKey: Self.displayNameKey)
            }
        } else {
            displayName = nil
        }
        if previousID != currentUserID {
            Task {
                await ProManager.shared.syncRevenueCatIdentity(userId: currentUserID)
            }
        }
    }

    /// Call once at app launch when Firebase may be configured (e.g. after adding GoogleService-Info.plist).
    public func configureIfNeeded() {
        guard FirebaseApp.app() == nil,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        updateState()
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                self?.updateState()
            }
        }
    }

    public func signInWithApple() async throws {
        guard FirebaseApp.app() != nil else {
            throw AuthError.notConfigured
        }
        authError = nil
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self as ASAuthorizationControllerPresentationContextProviding
        controller.performRequests()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
        }
    }

    public func signOut() throws {
        guard FirebaseApp.app() != nil else { return }
        try Auth.auth().signOut()
        displayName = nil
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
        updateState()
    }

    public enum AuthError: LocalizedError {
        case notConfigured
        case noCredential
        case cancelled
        case firebaseError(Error)

        public var errorDescription: String? {
            switch self {
            case .notConfigured: return "Firebase not configured"
            case .noCredential: return "No Apple credential"
            case .cancelled: return "Sign in cancelled"
            case .firebaseError(let e): return e.localizedDescription
            }
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {

    public nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let appleCred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idToken = appleCred.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                continuation?.resume(throwing: AuthError.noCredential)
                continuation = nil
                return
            }
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nil,
                fullName: appleCred.fullName
            )
            do {
                _ = try await Auth.auth().signIn(with: credential)
                if let name = appleCred.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    formatter.style = .default
                    let nameString = formatter.string(from: name).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !nameString.isEmpty {
                        UserDefaults.standard.set(nameString, forKey: Self.displayNameKey)
                        self.displayName = nameString
                    }
                }
                updateState()
                continuation?.resume(returning: ())
            } catch {
                continuation?.resume(throwing: AuthError.firebaseError(error))
            }
            continuation = nil
        }
    }

    public nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                continuation?.resume(throwing: AuthError.cancelled)
            } else {
                continuation?.resume(throwing: AuthError.firebaseError(error))
            }
            continuation = nil
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let w = AuthServicePresentation.window { return w }
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive }
            .flatMap { $0 as? UIWindowScene }
        return scene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}
