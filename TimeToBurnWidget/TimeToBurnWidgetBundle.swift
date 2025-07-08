//
//  TimeToBurnWidgetBundle.swift
//  TimeToBurnWidget
//
//  Created by Steven Taylor on 6/29/25.
//

import WidgetKit
import SwiftUI

@main
struct TimeToBurnWidgetBundle: WidgetBundle {
    init() {
        print("🌞 [Widget Bundle] 🚀 TimeToBurnWidgetBundle initialized")
    }
    
    var body: some Widget {
        TimeToBurnWidget()
        UVExposureLiveActivity()
    }
}
