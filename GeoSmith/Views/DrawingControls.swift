//
//  DrawingControls.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct DrawingControls: View {
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var layers: [LayerState]
    @Binding var selectedFeatures: Set<UUID>
    let selectedFeatureType: TrackFeatureType

    var body: some View {
        HStack {
            Button("New") {
                startNewFeature()
            }

            Button("Finish Drawing") {
                finishDrawing()
            }
            .disabled(!isDrawing)

            Button("Delete") {
                deleteSelectedFeatures()
            }
            .disabled(selectedFeatures.isEmpty)
        }
    }

    private func startNewFeature() {
        isDrawing = true
        currentPoints = []
    }

    private func finishDrawing() {
        guard currentPoints.count >= 2 else { return }

        let properties: [String: PropertyValue] = [
            "id": .string("\(selectedFeatureType.rawValue)-\(UUID().uuidString)"),
            "name": .string("New \(selectedFeatureType.rawValue.capitalized)")
        ]

        let newFeature = GeoJSONFeature(
            properties: properties,
            geometry: GeoJSONGeometry(
                type: .lineString,
                coordinates: currentPoints
            )
        )

        layers.append(LayerState(feature: newFeature))
        currentPoints = []
        isDrawing = false
    }

    private func deleteSelectedFeatures() {
        layers.removeAll { selectedFeatures.contains($0.id) }
        selectedFeatures.removeAll()
    }
}
