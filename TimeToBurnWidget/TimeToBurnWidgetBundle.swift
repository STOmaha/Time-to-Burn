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
    var body: some Widget {
        TimeToBurnWidget()
        UVExposureLiveActivity()
    }
}
