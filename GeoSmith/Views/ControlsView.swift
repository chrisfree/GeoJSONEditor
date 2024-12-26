//
//  ControlsView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct ControlsView: View {
    @Binding var editingState: EditingState
    @Binding var selectedFeatureType: TrackFeatureType
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var layers: [LayerState]
    @Binding var selectedFeatures: Set<UUID>

    var body: some View {
        VStack(spacing: 10) {
            if !editingState.isEnabled {
                FeatureTypePicker(selectedFeatureType: $selectedFeatureType)
                DrawingControls(
                    isDrawing: $isDrawing,
                    currentPoints: $currentPoints,
                    layers: $layers,
                    selectedFeatures: $selectedFeatures,
                    selectedFeatureType: selectedFeatureType
                )
            }
        }
        .padding()
    }
}
