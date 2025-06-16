import UIKit
import Flutter
import UserNotifications
import ActivityKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
      
    //Live Notification Handling
      
      let controller = window.rootViewController as! FlutterViewController
      let channel = FlutterMethodChannel(name: "com.yourapp/live_activity", binaryMessenger: controller.binaryMessenger)

      channel.setMethodCallHandler { call, result in
          if call.method == "startLiveActivity" {
              guard let args = call.arguments as? [String: Any] else { return }
              let rideId = args["rideId"] as? String ?? ""
              let eta = args["etaMinutes"] as? Int ?? 0
              let driver = args["driverName"] as? String ?? ""
              let car = args["carModel"] as? String ?? ""
              let plate = args["licensePlate"] as? String ?? ""
              let progress = args["progress"] as? Double ?? 0.0

              if #available(iOS 16.1, *) {
                  LiveActivityManager.startActivity(rideId, eta: eta, driver: driver, car: car, plate: plate, progress: progress)
              } else {
                  // Fallback on earlier versions
              }
              result("started")
          } else if call.method == "updateLiveActivity" {
              // make sure this matches EXACTLY
              guard let args = call.arguments as? [String: Any] else {
                  result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing args", details: nil))
                  return
              }

              print("📲 updateLiveActivity called from Flutter") // <-- add this
              if #available(iOS 16.1, *) {
                  LiveActivityManager.updateActivity(
                    eta: args["etaMinutes"] as? Int ?? 0,
                    progress: args["progress"] as? Double ?? 0.0
                  )
              } else {
                  // Fallback on earlier versions
              }
              result("updated")
          } else {
              result(FlutterMethodNotImplemented)
          }
      }
    // Register notification categories
    let trackAction = UNNotificationAction(
      identifier: "TRACK_ACTION",
      title: "Track",
      options: .foreground
    )
    
    let messageAction = UNNotificationAction(
      identifier: "MESSAGE_ACTION",
      title: "Message",
      options: .foreground
    )
    
    let category = UNNotificationCategory(
      identifier: "DELIVERY_CATEGORY",
      actions: [trackAction, messageAction],
      intentIdentifiers: [],
      options: [.customDismissAction, .allowInCarPlay, .hiddenPreviewsShowTitle]
    )
    
    UNUserNotificationCenter.current().setNotificationCategories([category])
    
    // Configure default presentation options
    UNUserNotificationCenter.current().delegate = self
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    
    @available(iOS 16.1, *)
    @objc class LiveActivityManager: NSObject {
        static var currentActivity: Activity<RideStatusAttributes>?
        
        @objc static func startActivity(_ rideId: String, eta: Int, driver: String, car: String, plate: String, progress: Double) {
            if #available(iOS 16.1, *) {
                let attributes = RideStatusAttributes(rideId: rideId)
                let state = RideStatusAttributes.ContentState(
                    etaMinutes: eta,
                    driverName: driver,
                    carModel: car,
                    licensePlate: plate,
                    progress: progress
                )
                do {
                    let activity = try Activity<RideStatusAttributes>.request(
                        attributes: attributes,
                        contentState: state,
                        pushType: nil
                    )
                    currentActivity = activity
                } catch {
                    print("Failed to start Live Activity: \(error)")
                }
            }
        }
        
        @objc static func updateActivity(eta: Int, progress: Double) {
            print("🟡 Trying to update Live Activity with ETA: \(eta), progress: \(progress)")
            
            if #available(iOS 16.1, *) {
                Task {
                    guard let activity = currentActivity else {
                        print("❌ No current activity found")
                        return
                    }
                    let updatedState = RideStatusAttributes.ContentState(
                        etaMinutes: eta,
                        driverName: "Driver",
                        carModel: "Model X",
                        licensePlate: "XYZ 123",
                        progress: progress
                    )
                    await activity.update(using: updatedState)
                    print("✅ Activity updated")
                }
            }
        }
    }
  
  // UNUserNotificationCenterDelegate methods
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .list])
    } else {
      completionHandler([.alert, .sound])
    }
  }
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
