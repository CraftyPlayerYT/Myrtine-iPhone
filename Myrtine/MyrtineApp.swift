import SwiftUI
import UIKit
import UserNotifications

@main
@MainActor
struct MyrtineApp: App {
    @UIApplicationDelegateAdaptor(MyrtineAppDelegate.self) private var appDelegate
    @State private var environment: AppEnvironment

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _environment = State(initialValue: AppEnvironment(
            inMemory: arguments.contains("-ui-testing"),
            useMocks: arguments.contains("-use-mocks")
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
                .preferredColorScheme(.light)
                .task { await environment.start() }
        }
    }
}

final class MyrtineAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .myrtineAPNSToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .myrtineAPNSError, object: error.localizedDescription)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        PushNotificationBridge.publish(notification.request.content.userInfo, persist: false)
        return []
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        PushNotificationBridge.publish(response.notification.request.content.userInfo, persist: true)
    }
}

enum PushNotificationBridge {
    private static let pendingKey = "myrtine.pending-push"

    static func publish(_ userInfo: [AnyHashable: Any], persist: Bool) {
        guard let kind = userInfo["myrtine_kind"] as? String,
              let id = userInfo["myrtine_id"] as? String else { return }
        let payload = ["kind": kind, "id": id, "open": persist ? "true" : "false"]
        if persist { UserDefaults.standard.set(payload, forKey: pendingKey) }
        NotificationCenter.default.post(name: .myrtinePush, object: nil, userInfo: payload)
    }

    static func takePending() -> [String: String]? {
        guard let payload = UserDefaults.standard.dictionary(forKey: pendingKey) as? [String: String] else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return payload
    }
}

extension Notification.Name {
    static let myrtinePush = Notification.Name("fr.myrtine.push")
    static let myrtineAPNSToken = Notification.Name("fr.myrtine.apns-token")
    static let myrtineAPNSError = Notification.Name("fr.myrtine.apns-error")
}
