//
//  FeaturePointsView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI
import MapKit

struct FeaturePointsView: View {
    @EnvironmentObject private var selectionState: SelectionState
    let coordinates: [[Double]]
    let layerId: UUID
    @Binding var editingState: EditingState
    @Binding var layers: [LayerState]
    @State private var isPointAnimating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(coordinates.indices, id: \.self) { index in
                PointRowView(
                    index: index,
                    coordinate: coordinates[index],
                    isSelected: selectionState.selectedPoints.contains(index),
                    isAnimating: isPointAnimating && selectionState.selectedPoints.contains(index)
                )
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .modifiers(.shift)
                        .onEnded { _ in
                            selectionState.selectPoint(index, mode: .range)
                        }
                )
                .gesture(
                    TapGesture()
                        .modifiers(.command)
                        .onEnded { _ in
                            selectionState.selectPoint(index, mode: .additive)
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            if !NSEvent.modifierFlags.contains(.shift) &&
                               !NSEvent.modifierFlags.contains(.command) {
                                handleRegularClick(index)
                            }
                        }
                )
                .contextMenu {
                    if !selectionState.selectedPoints.isEmpty {
                        Button("Duplicate selection to new layer") {
                            duplicateSelectionToNewLayer()
                        }
                    }
                    if selectionState.selectedPoints.count == 1 {
                        Button("Delete point") {
                            deletePoint()
                        }

                        Button("Insert point after...") {
                            print("Insert point after \(selectionState.selectedPoints)")
                            insertPoint()
                        }
                    }
                }
            }
        }
        .padding(8)
        .cornerRadius(6)
    }

    private func handleRegularClick(_ index: Int) {
        if !editingState.isEnabled {
            enterEditMode(forPoint: index)
        } else {
            selectionState.selectPoint(index, mode: .single)
        }
    }

    private func duplicateSelectionToNewLayer() {
        guard !selectionState.selectedPoints.isEmpty else { return }

        // Find the current layer
        guard let currentLayer = layers.first(where: { $0.id == layerId }) else { return }

        // Create new coordinates array with only selected points in selection order
        let selectedCoordinates = selectionState.selectedPoints.compactMap { index in
            coordinates[safe: index]
        }

        // Create new feature properties, copying the original but updating the name
        var newProperties = currentLayer.feature.properties
        newProperties["name"] = PropertyValue.string("Unnamed segment")

        // Create new geometry with duplicated points
        let newGeometry = GeoJSONGeometry(
            type: currentLayer.feature.geometry.type,
            coordinates: selectedCoordinates
        )

        // Create new feature with duplicated points
        let newFeature = GeoJSONFeature(
            type: currentLayer.feature.type,
            properties: newProperties,
            geometry: newGeometry
        )

        // Create new layer
        let newLayer = LayerState(
            feature: newFeature,
            isVisible: true
        )

        // Add new layer to layers array
        layers.append(newLayer)

        // Switch selection to new layer
        editingState.selectedFeatureId = newFeature.id
        selectionState.selectPoint(0, mode: .single) // Select first point in new layer
    }

    func calculateMidpoint(coordinate1: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> CLLocationCoordinate2D {

        let midLatitude = (coordinate1.latitude + coordinate2.latitude) / 2

        let midLongitude = (coordinate1.longitude + coordinate2.longitude) / 2

        return CLLocationCoordinate2D(latitude: midLatitude, longitude: midLongitude)

    }

    private func deletePoint() {
        guard !selectionState.selectedPoints.isEmpty else { return }

        // Find the current layer
        guard let currentLayerIndex = layers.firstIndex(where: { $0.id == layerId }) else { return }

        // Get the selected point index
        guard let selectedPointIndex = selectionState.selectedPoints.first else { return }

        // Ensure we don't delete the last point
        if layers[currentLayerIndex].feature.geometry.coordinates.count > 1 {
            // Remove the point at the selected index
            layers[currentLayerIndex].feature.geometry.coordinates.remove(at: selectedPointIndex)

            // Clear selection after deletion
            selectionState.clearPointSelection()
        }
    }

    private func insertPoint() {
        guard !selectionState.selectedPoints.isEmpty else { return }

        // Find the current layer
        guard let currentLayerIndex = layers.firstIndex(where: { $0.id == layerId }) else { return }

        // Get the selected point index
        guard let selectedPointIndex = selectionState.selectedPoints.first else { return }

        // Get insertion index (inserting after the selected point)
        let insertionIndex = min(selectedPointIndex + 1, layers[currentLayerIndex].feature.geometry.coordinates.count)

        let pointA = layers[currentLayerIndex].feature.geometry.coordinates[selectedPointIndex]
        let insertAfterCoordinate = CLLocationCoordinate2D(
            latitude: pointA[1],
            longitude: pointA[0]
        )

        let pointB = layers[currentLayerIndex].feature.geometry.coordinates[insertionIndex]
        let insertBeforeCoordinate = CLLocationCoordinate2D(
            latitude: pointB[1],
            longitude: pointB[0]
        )

        // Create the new coordinate
        let newCoordinate = calculateMidpoint(
            coordinate1: insertAfterCoordinate,
            coordinate2: insertBeforeCoordinate
        )

        // Insert the point
        insertPoint(
            coordinate: newCoordinate,
            at: insertionIndex,
            into: &layers[currentLayerIndex].feature
        )

        // Clear selection after insertion
        selectionState.clearPointSelection()
    }

    private func insertPoint(coordinate: CLLocationCoordinate2D, at index: Int, into feature: inout GeoJSONFeature) {
        // Ensure the index is valid
        guard index >= 0 && index <= feature.geometry.coordinates.count else {
            print("Invalid index for insertion")
            return
        }

        // Convert CLLocationCoordinate2D to [Double] format (longitude, latitude)
        let coordinateArray = [coordinate.longitude, coordinate.latitude]

        // Validate geometry type
        guard feature.geometry.type == "LineString" else {
            print("Unsupported geometry type: \(feature.geometry.type)")
            return
        }

        // Insert the coordinate array at the specified index
        feature.geometry.coordinates.insert(coordinateArray, at: index)
    }

    private func enterEditMode(forPoint index: Int) {
        editingState.isEnabled = true
        editingState.selectedFeatureId = layerId
        selectionState.selectPoint(index, mode: .single)

        if let layerIndex = layers.firstIndex(where: { $0.id == layerId }) {
            editingState.modifiedCoordinates = layers[layerIndex].feature.geometry.coordinates
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isPointAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isPointAnimating = false
        }
    }
}

struct PointRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let index: Int
    let coordinate: [Double]
    let isSelected: Bool
    let isAnimating: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .foregroundStyle(isSelected ? .primary : .secondary)
                .font(.system(size: 5))
                .padding(.trailing, 5)

            Text("Point \(index + 1)")
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()

            Text(formatCoordinate(coordinate))
                .font(.caption)
                .monospaced()
                .foregroundStyle(isSelected ? .primary : .secondary)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15) : .clear)
        )
    }

    private func formatCoordinate(_ coordinate: [Double]) -> String {
        guard coordinate.count >= 2 else { return "Invalid" }
        return String(format: "[%.6f, %.6f]", coordinate[1], coordinate[0])
    }
}
