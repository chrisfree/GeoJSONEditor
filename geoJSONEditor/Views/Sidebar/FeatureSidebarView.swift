//
//  FeatureSidebarView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct FeatureSidebarView: View {
    @EnvironmentObject private var selectionState: SelectionState
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState
    @Binding var selectedFeatureType: TrackFeatureType
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]

    var body: some View {
        VStack {
            FeatureListView(
                selectedFeatures: $selectedFeatures,
                layers: $layers,
                editingState: $editingState
            )

            Divider()

            ControlsView(
                editingState: $editingState,
                selectedFeatureType: $selectedFeatureType,
                isDrawing: $isDrawing,
                currentPoints: $currentPoints,
                layers: $layers,
                selectedFeatures: $selectedFeatures
            )
        }
    }
}
