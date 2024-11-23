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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(coordinates.indices, id: \.self) { index in
                PointRowView(
                    index: index,
                    coordinate: coordinates[index],
                    isSelected: editingState.selectedPointIndex == index,
                    isAnimating: isPointAnimating && editingState.selectedPointIndex == index,
                    onDoubleTap: { handlePointSelection(index) }
                )
            }
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    private func handlePointSelection(_ index: Int) {
        if editingState.isEnabled && editingState.selectedPointIndex == index {
            exitEditMode()
        } else {
            enterEditMode(forPoint: index)
        }
    }

    private func enterEditMode(forPoint index: Int) {
        editingState.isEnabled = true
        editingState.selectedFeatureId = layerId
        editingState.selectedPointIndex = index

        if let layerIndex = layers.firstIndex(where: { $0.feature.id == layerId }) {
            editingState.modifiedCoordinates = layers[layerIndex].feature.geometry.coordinates
        }

        for i in 0..<layers.count {
            layers[i].isVisible = (layers[i].feature.id == layerId)
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
        editingState.selectedPointIndex = nil
        editingState.modifiedCoordinates = nil

        for i in 0..<layers.count {
            layers[i].isVisible = true
        }
    }
}


struct PointRowView: View {
    let index: Int
    let coordinate: [Double]
    let isSelected: Bool
    let isAnimating: Bool
    let onDoubleTap: () -> Void

    var body: some View {
        HStack {
            Text("Point \(index + 1)")
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()

            coordinateView
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var coordinateView: some View {
        Text(formatCoordinate(coordinate))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
    }

    private func formatCoordinate(_ coordinate: [Double]) -> String {
        guard coordinate.count >= 2 else { return "Invalid" }
        return String(format: "%.6f, %.6f", coordinate[1], coordinate[0])
    }
}
