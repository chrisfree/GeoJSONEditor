//
//  FeaturePointsView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct FeaturePointsView: View {
    let coordinates: [[Double]]
    let layerId: UUID
    @Binding var editingState: EditingState
    @Binding var layers: [LayerState]
    @State private var isPointAnimating: Bool = false
    @State private var selectedIndices: [Int] = [] // Changed to array to maintain order
    @State private var lastSelectedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(coordinates.indices, id: \.self) { index in
                PointRowView(
                    index: index,
                    coordinate: coordinates[index],
                    isSelected: selectedIndices.contains(index),
                    isAnimating: isPointAnimating && selectedIndices.contains(index)
                )
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .modifiers(.shift)
                        .onEnded { _ in
                            handleShiftClick(index)
                        }
                )
                .gesture(
                    TapGesture()
                        .modifiers(.command)
                        .onEnded { _ in
                            handleCommandClick(index)
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
                    if !selectedIndices.isEmpty {
                        Button("Duplicate Selection to New Layer") {
                            duplicateSelectionToNewLayer()
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
            selectedIndices = [index]
            lastSelectedIndex = index
        }
    }

    private func handleCommandClick(_ index: Int) {
        guard editingState.isEnabled else {
            enterEditMode(forPoint: index)
            return
        }

        if let existingIndex = selectedIndices.firstIndex(of: index) {
            // If already selected, remove it
            selectedIndices.remove(at: existingIndex)
        } else {
            // If not selected, add it to the end to maintain order
            selectedIndices.append(index)
        }
        lastSelectedIndex = index
    }

    private func handleShiftClick(_ index: Int) {
        guard editingState.isEnabled, let last = lastSelectedIndex else {
            handleRegularClick(index)
            return
        }

        let range = min(last, index)...max(last, index)
        // Convert to array to maintain order
        let newIndices = Array(range)

        // Remove any existing indices in the range
        selectedIndices.removeAll { newIndices.contains($0) }
        // Add all new indices at the end
        selectedIndices.append(contentsOf: newIndices)
    }

    private func duplicateSelectionToNewLayer() {
        guard !selectedIndices.isEmpty else { return }

        // Find the current layer
        guard let currentLayer = layers.first(where: { $0.id == layerId }) else { return }

        // Create new coordinates array with only selected points in selection order
        let selectedCoordinates = selectedIndices.compactMap { index in
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
        selectedIndices = Array(0..<selectedCoordinates.count)
        lastSelectedIndex = selectedCoordinates.count - 1
    }

    private func enterEditMode(forPoint index: Int) {
        editingState.isEnabled = true
        editingState.selectedFeatureId = layerId
        selectedIndices = [index]
        lastSelectedIndex = index

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

    private func exitEditMode() {
        editingState.isEnabled = false
        editingState.selectedFeatureId = nil
        editingState.modifiedCoordinates = nil
        selectedIndices.removeAll()
        lastSelectedIndex = nil
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
