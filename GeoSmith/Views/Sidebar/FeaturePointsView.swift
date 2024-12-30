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
    let layerId: UUID
    @Binding var editingState: EditingState
    @Binding var layers: [LayerState]
    @State private var isPointAnimating: Bool = false

    // Updated featureCoordinates property to handle all geometry types
    private var featureCoordinates: [[Double]] {
        guard let layer = layers.first(where: { $0.id == layerId }),
              let geometry = layer.feature.geometry else { return [] }
        
        switch geometry.type {
        case .point:
            if let point = geometry.pointCoordinates {
                return [point]
            }
        case .multiPoint:
            return geometry.multiPointCoordinates ?? []
        case .lineString:
            return geometry.lineStringCoordinates ?? []
        case .multiLineString:
            // Flatten all linestrings into a single array of points
            return geometry.multiLineStringCoordinates?.flatMap { $0 } ?? []
        case .polygon:
            // Flatten only the exterior ring points
            if let polygon = geometry.polygonCoordinates, !polygon.isEmpty {
                return polygon[0] // Return exterior ring points
            }
        case .multiPolygon:
            // Return first polygon's exterior ring points
            if let multiPolygon = geometry.multiPolygonCoordinates,
               !multiPolygon.isEmpty,
               !multiPolygon[0].isEmpty {
                return multiPolygon[0][0] // First polygon's exterior ring
            }
        case .geometryCollection:
            if let firstGeometry = geometry.geometryCollectionGeometries?.first {
                return getCoordinates(from: firstGeometry)
            }
        }
        return []
    }
    
    private func getCoordinates(from geometry: GeoJSONGeometry) -> [[Double]] {
        switch geometry.type {
        case .point:
            if let point = geometry.pointCoordinates {
                return [point]
            }
        case .multiPoint:
            return geometry.multiPointCoordinates ?? []
        case .lineString:
            return geometry.lineStringCoordinates ?? []
        case .multiLineString:
            return geometry.multiLineStringCoordinates?.flatMap { $0 } ?? []
        case .polygon:
            if let polygon = geometry.polygonCoordinates, !polygon.isEmpty {
                return polygon[0]
            }
        case .multiPolygon:
            if let multiPolygon = geometry.multiPolygonCoordinates,
               !multiPolygon.isEmpty,
               !multiPolygon[0].isEmpty {
                return multiPolygon[0][0]
            }
        case .geometryCollection:
            if let first = geometry.geometryCollectionGeometries?.first {
                return getCoordinates(from: first)
            }
        }
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(featureCoordinates.indices, id: \.self) { index in
                PointRowView(
                    index: index,
                    coordinate: featureCoordinates[index],
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
        guard let currentLayer = layers.first(where: { $0.id == layerId }),
              let geometry = currentLayer.feature.geometry else { return }

        // Create new coordinates array with only selected points in selection order
        let selectedCoordinates = selectionState.selectedPoints.compactMap { index in
            featureCoordinates[safe: index]
        }

        // Create new feature properties
        var newProperties = currentLayer.feature.properties ?? [:]
        newProperties["name"] = .string("Unnamed segment")

        // Create new geometry with duplicated points
        let newGeometry = GeoJSONGeometry(lineString: selectedCoordinates)

        // Create new feature with duplicated points
        let newFeature = GeoJSONFeature(
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
        guard let currentLayerIndex = layers.firstIndex(where: { $0.id == layerId }),
              let geometry = layers[currentLayerIndex].feature.geometry,
              let coordinates = geometry.lineStringCoordinates,
              coordinates.count > 1 else { return }

        // Get the selected point index
        guard let selectedPointIndex = selectionState.selectedPoints.first else { return }

        // Create new coordinates array without the selected point
        var newCoords = coordinates
        newCoords.remove(at: selectedPointIndex)

        // Update feature with new geometry
        var updatedFeature = layers[currentLayerIndex].feature
        updatedFeature.geometry = GeoJSONGeometry(lineString: newCoords)
        layers[currentLayerIndex].feature = updatedFeature

        // Clear selection after deletion
        selectionState.clearPointSelection()
    }

    private func insertPoint() {
        guard !selectionState.selectedPoints.isEmpty else { return }

        // Find the current layer
        guard let currentLayerIndex = layers.firstIndex(where: { $0.id == layerId }),
              let geometry = layers[currentLayerIndex].feature.geometry,
              let coordinates = geometry.lineStringCoordinates else { return }

        // Get the selected point index
        guard let selectedPointIndex = selectionState.selectedPoints.first else { return }

        // Get insertion index (inserting after the selected point)
        let insertionIndex = min(selectedPointIndex + 1, coordinates.count)

        // Get coordinates for calculation
        guard let pointA = coordinates[safe: selectedPointIndex],
              let pointB = coordinates[safe: insertionIndex] else { return }

        let insertAfterCoordinate = CLLocationCoordinate2D(
            latitude: pointA[1],
            longitude: pointA[0]
        )

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
        var newCoords = coordinates
        newCoords.insert([newCoordinate.longitude, newCoordinate.latitude], at: insertionIndex)

        // Update feature with new geometry
        var updatedFeature = layers[currentLayerIndex].feature
        updatedFeature.geometry = GeoJSONGeometry(lineString: newCoords)
        layers[currentLayerIndex].feature = updatedFeature

        // Clear selection after insertion
        selectionState.clearPointSelection()
    }

    private func enterEditMode(forPoint index: Int) {
        editingState.isEnabled = true
        editingState.selectedFeatureId = layerId
        selectionState.selectPoint(index, mode: .single)
        
        // Store modified coordinates
        if let layerIndex = layers.firstIndex(where: { $0.id == layerId }),
           let feature = layers[layerIndex].feature as? GeoJSONFeature,
           let geometry = feature.geometry,
           let lineStringCoords = geometry.lineStringCoordinates {
            editingState.modifiedCoordinates = lineStringCoords
        }
        
        // Animation section remains the same
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
