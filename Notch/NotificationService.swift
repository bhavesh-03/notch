//
//  NotificationService.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func postTimerFinished(duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "Your \(Int(duration / 60))-minute session is done."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "timer-finished", content: content, trigger: nil)
        center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}