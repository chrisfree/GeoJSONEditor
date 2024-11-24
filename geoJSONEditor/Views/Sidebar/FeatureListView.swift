//
//  FeatureListView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct FeatureListView: View {
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState

    var body: some View {
        List(selection: $selectedFeatures) {
            ForEach(layers) { layer in
                FeatureRowView(layer: layer,
                             layers: $layers,
                             editingState: $editingState)
            }
            .onMove { source, destination in
                layers.move(fromOffsets: source, toOffset: destination)
                // After moving, we need to update visibility based on selection
                if let selectedId = selectedFeatures.first {
                    updateLayerVisibility(for: selectedId)
                }
            }
            .moveDisabled(false)
        }
        .listStyle(.sidebar)
        .accentColor(.secondary)
        .onChange(of: selectedFeatures) { oldValue, newValue in
            handleSelectionChange(newValue)
        }
    }

    private func handleSelectionChange(_ newSelection: Set<UUID>) {
        if editingState.isEnabled, let selected = newSelection.first {
            editingState.selectedFeatureId = selected
            updateLayerVisibility(for: selected)
        }
    }

    private func updateLayerVisibility(for selectedId: UUID) {
        for i in 0..<layers.count {
            layers[i].isVisible = layers[i].feature.id == selectedId
        }
    }
}
