import ActivityKit
import SwiftUI

public struct DeliveryAttributes: ActivityAttributes, Codable {
    public struct ContentState: Codable, Hashable {
        public var driverName: String
        public var vehicleInfo: String
        public var estimatedTime: String
        public var progress: Double
        public var driverImageURL: String
        public var vehicleImageURL: String
        
        public init(
            driverName: String,
            vehicleInfo: String,
            estimatedTime: String,
            progress: Double,
            driverImageURL: String,
            vehicleImageURL: String
        ) {
            self.driverName = driverName
            self.vehicleInfo = vehicleInfo
            self.estimatedTime = estimatedTime
            self.progress = progress
            self.driverImageURL = driverImageURL
            self.vehicleImageURL = vehicleImageURL
        }
    }
    
    public var deliveryId: String
    public var title: String
    
    public init(deliveryId: String, title: String) {
        self.deliveryId = deliveryId
        self.title = title
    }
} 