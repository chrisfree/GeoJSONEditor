//
//  LayerState.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct LayerState: Identifiable {
    let id: UUID
    var feature: GeoJSONFeature
    var isVisible: Bool
    
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
    }
}
