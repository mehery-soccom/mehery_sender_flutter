//
//  NotificationViewController.swift
//  NotificationContentExtension
//
//  Created by Pranjal on 11/04/25.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var vehicleInfoLabel: UILabel!
    @IBOutlet weak var driverImageView: UIImageView!
    @IBOutlet weak var carImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure driver image view
        driverImageView.layer.cornerRadius = 20 // Half of width
        driverImageView.clipsToBounds = true
        driverImageView.contentMode = .scaleAspectFill
        
        // Configure car image view
        carImageView.contentMode = .scaleAspectFit
        
        // Configure progress view
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 2)
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        progressView.progressTintColor = UIColor.systemBlue
        progressView.trackTintColor = UIColor.systemGray5
    }
    
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        
        // Set title and vehicle info
        titleLabel.text = content.title
        vehicleInfoLabel.text = content.subtitle
        
        // Set progress
        if let progress = content.userInfo["progress"] as? Double {
            progressView.progress = Float(progress)
        }
        
        // Load driver image
        if let driverAttachment = content.attachments.first(where: { $0.identifier == "driverImage" }) {
            if let data = try? Data(contentsOf: driverAttachment.url),
               let image = UIImage(data: data) {
                driverImageView.image = image
            }
        }
        
        // Load car image
        if let carAttachment = content.attachments.first(where: { $0.identifier == "vehicleImage" }) {
            if let data = try? Data(contentsOf: carAttachment.url),
               let image = UIImage(data: data) {
                carImageView.image = image
            }
        }
    }
}
