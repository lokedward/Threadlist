// NotificationManager.swift
// Handles local notifications for "Night Out" nudges

import Foundation
import UserNotifications
import SwiftUI
internal import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @AppStorage("notificationsNightOutEnabled") var isNightOutEnabled = false {
        didSet {
            if isNightOutEnabled {
                scheduleNightOutNudges()
            } else {
                cancelNightOutNudges()
            }
        }
    }
    
    // Deep link action identifier
    static let nightOutActionID = "PLAN_OUTFIT_ACTION"
    static let nightOutCategoryID = "NIGHT_OUT_CATEGORY"
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted && self.isNightOutEnabled {
                    self.scheduleNightOutNudges()
                }
            }
        }
    }
    
    func scheduleNightOutNudges() {
        guard isAuthorized else { return }
        
        // Define the content
        let content = UNMutableNotificationContent()
        content.title = "Planning a Night Out?"
        content.body = "Let the AI Stylist curate your perfect look for this evening. ✨"
        content.sound = .default
        content.categoryIdentifier = Self.nightOutCategoryID
        
        // Schedule for Thursday 6:00 PM
        scheduleWeeklyNotification(weekday: 5, hour: 18, identifier: "nightOut_thursday", content: content)
        
        // Schedule for Friday 6:00 PM
        scheduleWeeklyNotification(weekday: 6, hour: 18, identifier: "nightOut_friday", content: content)
    }
    
    private func scheduleWeeklyNotification(weekday: Int, hour: Int, identifier: String, content: UNNotificationContent) {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday // 1 = Sunday, 5 = Thursday, 6 = Friday
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Scheduled \(identifier) for weekday \(weekday) at \(hour):00")
            }
        }
    }
    
    func cancelNightOutNudges() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nightOut_thursday", "nightOut_friday"])
        print("Cancelled Night Out nudges")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Post a notification that the app UI can listen for to navigate
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToStylist"), object: nil)
        completionHandler()
    }
}
