import ActivityKit
import WidgetKit
import SwiftUI

struct RideStatusAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var etaMinutes: Int
        var driverName: String
        var carModel: String
        var licensePlate: String
        var progress: Double // 0.0 to 1.0
    }

    var rideId: String
}

@available(iOS 16.2, *)
struct LiveActivityExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideStatusAttributes.self) { context in
            // Lock Screen / Banner UI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pickup in \(context.state.etaMinutes) min")
                        .font(.headline)
                        .bold()
                    Spacer()
                    Text("Uber")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text("\(context.state.licensePlate) • \(context.state.carModel)")
                    .font(.subheadline)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    // Driver avatar (placeholder)
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())

                    // Car image (placeholder)
                    Image(systemName: "car.fill")
                        .resizable()
                        .frame(width: 40, height: 25)

                    Spacer()

                    // Progress bar with car icon
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color.blue)
                                .frame(width: geo.size.width * context.state.progress, height: 6)

                            Image(systemName: "car.fill")
                                .resizable()
                                .frame(width: 16, height: 12)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .offset(x: geo.size.width * context.state.progress - 8)
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(.black)
            .foregroundColor(.white)
        } dynamicIsland: { context in
            // Optional: Dynamic Island UI here
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Pickup in \(context.state.etaMinutes) min")
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                Text("\(context.state.etaMinutes)m")
            } minimal: {
                Text("\(context.state.etaMinutes)")
            }
        }
    }
}
