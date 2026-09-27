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

    func postTimerFinished(duration: TimeInterval, playsSound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = Self.timerFinishedBody(duration: duration)
        content.sound = playsSound ? .default : nil

        let request = UNNotificationRequest(identifier: "timer-finished", content: content, trigger: nil)
        center.add(request)
    }

    /// "Your 25-minute timer is done" read wrong for short and long timers ("0-minute"), so the
    /// length is spelled out: "Your timer for 30 seconds is done."
    static func timerFinishedBody(duration: TimeInterval) -> String {
        "Your timer for \(TimerFormat.spoken(seconds: Int(duration.rounded()))) is done."
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}