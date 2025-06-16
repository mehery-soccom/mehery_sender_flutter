import UserNotifications
import ActivityKit

// Remove the Runner import and just use the file directly
// since it's in the same target now
// @_implementationOnly import Runner

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent else { return }
        
        // Get the custom data from the notification payload
        guard let templateId = request.content.userInfo["template_id"] as? String else {
            contentHandler(bestAttemptContent)
            return
        }
        
        switch templateId {
        case "delivery":
            handleDeliveryNotification(bestAttemptContent)
        case "score":
            handleScoreNotification(bestAttemptContent)
        default:
            handleStandardNotification(bestAttemptContent)
        }
    }
    
    func handleDeliveryNotification(_ content: UNMutableNotificationContent) {
        guard let driverName = content.userInfo["driver_name"] as? String,
              let vehicleInfo = content.userInfo["vehicle_info"] as? String,
              let estimatedTime = content.userInfo["estimated_time"] as? String,
              let driverImageUrl = content.userInfo["driver_image_url"] as? String,
              let vehicleImageUrl = content.userInfo["vehicle_image_url"] as? String,
              let progress = content.userInfo["progress"] as? Double else {
            contentHandler?(content)
            return
        }
        
        var attachments: [UNNotificationAttachment] = []
        
        // Download the driver image
        if let url = URL(string: driverImageUrl),
           let imageData = try? Data(contentsOf: url) {
            let tempDirectory = FileManager.default.temporaryDirectory
            let driverImagePath = tempDirectory.appendingPathComponent("driver_image.jpg")
            try? imageData.write(to: driverImagePath)
            
            if let attachment = try? UNNotificationAttachment(
                identifier: "driverImage",
                url: driverImagePath,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "AAPLCustomBadgeTypeCircular"]) {
                attachments.append(attachment)
            }
        }
        
        // Download the vehicle image
        if let url = URL(string: vehicleImageUrl),
           let imageData = try? Data(contentsOf: url) {
            let tempDirectory = FileManager.default.temporaryDirectory
            let vehicleImagePath = tempDirectory.appendingPathComponent("vehicle_image.jpg")
            try? imageData.write(to: vehicleImagePath)
            
            if let attachment = try? UNNotificationAttachment(
                identifier: "vehicleImage",
                url: vehicleImagePath,
                options: nil) {
                attachments.append(attachment)
            }
        }
        
        content.attachments = attachments
        content.categoryIdentifier = "DELIVERY_CATEGORY"
        content.interruptionLevel = .timeSensitive
        
        // Create custom notification layout
        content.title = "Pickup in \(estimatedTime)"
        content.subtitle = "\(vehicleInfo)"
        content.threadIdentifier = "delivery_tracking"
        
        // Add custom user info for layout
        var userInfo = content.userInfo
        userInfo["progress"] = progress
        userInfo["style"] = "tracking"
        content.userInfo = userInfo
        
        print("Starting Live Activity with data:")
        print("- Driver: \(driverName)")
        print("- Vehicle: \(vehicleInfo)")
        print("- Time: \(estimatedTime)")
        print("- Progress: \(progress)")
        
        // Start Live Activity
        let attributes = DeliveryAttributes(
            deliveryId: UUID().uuidString,
            title: content.title
        )
        
        let contentState = DeliveryAttributes.ContentState(
            driverName: driverName,
            vehicleInfo: vehicleInfo,
            estimatedTime: estimatedTime,
            progress: progress,
            driverImageURL: driverImageUrl,
            vehicleImageURL: vehicleImageUrl
        )
        
        if #available(iOS 16.1, *) {
            // Check if Live Activities are supported
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("❌ Live Activities not enabled for this device/app")
                contentHandler?(content)
                return
            }

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: .token
                )
                print("✅ Successfully started Live Activity: \(activity.id)")
                
                // Print all active activities
                print("Current Live Activities: \(Activity<DeliveryAttributes>.activities.map { $0.id })")
            } catch {
                print("❌ Error starting Live Activity: \(error.localizedDescription)")
            }
        } else {
            print("❌ Live Activities not available - requires iOS 16.1+")
        }
        
        contentHandler?(content)
    }
    
    func handleScoreNotification(_ content: UNMutableNotificationContent) {
        guard let team1 = content.userInfo["team1"] as? String,
              let team2 = content.userInfo["team2"] as? String,
              let score1 = content.userInfo["score1"] as? String,
              let score2 = content.userInfo["score2"] as? String else {
            contentHandler?(content)
            return
        }
        
        // Customize the notification content
        content.title = "Match Update"
        content.subtitle = "\(team1) \(score1) - \(score2) \(team2)"
        
        contentHandler?(content)
    }
    
    func handleStandardNotification(_ content: UNMutableNotificationContent) {
        // Just pass through the content as is
        contentHandler?(content)
    }
    
    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler = contentHandler,
              let bestAttemptContent = bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }
}
