//
//  LiveActivityExtensionBundle.swift
//  LiveActivityExtension
//
//  Created by Pranjal on 14/04/25.
//

import WidgetKit
import SwiftUI

@main
struct LiveActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        LiveActivityExtension()
        LiveActivityExtensionControl()
        LiveActivityExtensionLiveActivity()
    }
}
