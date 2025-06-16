import ActivityKit
import SwiftUI

struct DeliveryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var driverName: String
        var vehicleInfo: String
        var estimatedTime: String
        var progress: Double
        var driverImageURL: String
        var vehicleImageURL: String
    }
    
    var deliveryId: String
    var title: String
} 