//
//  FeatureSidebarView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI
import MapKit

struct FeatureSidebarView: View {
    @EnvironmentObject private var selectionState: SelectionState
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState
    @Binding var selectedFeatureType: TrackFeatureType
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var region: MKCoordinateRegion
    @Binding var shouldForceUpdate: Bool

    var body: some View {
        VStack {
            FeatureListView(
                selectedFeatures: $selectedFeatures,
                layers: $layers,
                editingState: $editingState,
                region: $region,
                shouldForceUpdate: $shouldForceUpdate
            )
        }
    }
}
