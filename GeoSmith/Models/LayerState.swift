//
//  LayerState.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI
import AppKit

struct LayerState: Identifiable, Equatable {
    let id: UUID
    var feature: GeoJSONFeature
    var isVisible: Bool
    private let layerColor: NSColor
    
    var lineStringCoordinates: [[Double]]? {
        if case let .lineString = feature.geometry.type {
            return feature.geometry.lineStringCoordinates
        }
        return nil
    }
    
    init(feature: GeoJSONFeature, isVisible: Bool = true) {
        self.id = feature.id
        self.feature = feature
        self.isVisible = isVisible
        
        // Generate a unique color based on the feature's ID
        let components = feature.id.uuid
        let red = CGFloat(components.0) / 255.0
        let green = CGFloat(components.1) / 255.0
        let blue = CGFloat(components.2) / 255.0
        
        // Create color with some constraints to ensure visibility
        self.layerColor = NSColor(
            red: min(max(red, 0.2), 0.8),
            green: min(max(green, 0.2), 0.8),
            blue: min(max(blue, 0.2), 0.8),
            alpha: 1.0
        )
        
        print("Creating LayerState \(feature.id)\n- Generated color: \(self.layerColor)")
    }
    
    var color: NSColor {
        print("Getting color for layer \(id): \(layerColor)")
        return layerColor
    }
    
    static func == (lhs: LayerState, rhs: LayerState) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isVisible == rhs.isVisible &&
               lhs.feature.id == rhs.feature.id
    }
}
