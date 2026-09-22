//
//  SyncManager.swift
//  taika
//
//  Cloud progress sync API. Firestore/gRPC was unlinked from the app target
//  (PreviewShell watchdog / launch budget). Methods are local no-ops until
//  FirebaseFirestore is re-added as a package product and this file restored.
//

import Foundation

@MainActor
public final class SyncManager: ObservableObject {

    public static let shared = SyncManager()

    @Published public private(set) var lastPushAt: Date?
    @Published public private(set) var lastPullAt: Date?
    @Published public private(set) var syncError: String?
    @Published public private(set) var lastCloudUpdatedAt: Date?

    public var diagnosticsSummary: String {
        "cloud sync: off (Firestore unlinked)"
    }

    private init() {}

    public func onUserDidLogin(userId: String) {
        _ = userId
    }

    public func restoreIfNeeded(userId: String, force: Bool = false) {
        _ = userId
        _ = force
    }

    public func pushNow() async {}

    public func pullAndApply(userId: String) async {
        _ = userId
    }

    public func schedulePush() {}
}
