//
//  EditingState.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct EditingState {
    var isEnabled: Bool = false
    var selectedFeatureId: UUID?
    var modifiedCoordinates: [[Double]]?
    var isDraggingPoint: Bool = false
    var selectedPointIndex: Int? // Add this to track selected point
}
