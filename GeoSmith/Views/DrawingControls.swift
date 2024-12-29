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

            Button(buttonLabel) {
                finishDrawing()
            }
            .disabled(!isDrawing || !canFinishDrawing)

            Button("Delete") {
                deleteSelectedFeatures()
            }
            .disabled(selectedFeatures.isEmpty)
        }
    }
    
    private var buttonLabel: String {
        switch selectedFeatureType {
        case .area: return "Close Polygon"
        case .point: return "Place Point"
        default: return "Finish Drawing"
        }
    }
    
    private var canFinishDrawing: Bool {
        guard isDrawing else { return false }
        switch selectedFeatureType {
        case .point: return currentPoints.count >= 1
        case .area: return currentPoints.count >= 3
        default: return currentPoints.count >= 2
        }
    }

    private func startNewFeature() {
        isDrawing = true
        currentPoints = []
    }

    private func finishDrawing() {
        // Validate minimum points based on feature type
        switch selectedFeatureType {
        case .point where currentPoints.count < 1: return
        case .area where currentPoints.count < 3: return
        case _ where currentPoints.count < 2: return
        default: break
        }

        let properties: [String: PropertyValue] = [
            "id": .string("\(selectedFeatureType.rawValue)-\(UUID().uuidString)"),
            "name": .string("New \(selectedFeatureType.rawValue.capitalized)"),
            "type": .string(selectedFeatureType.rawValue)
        ]

        let geometry: GeoJSONGeometry
        switch selectedFeatureType {
        case .point:
            geometry = GeoJSONGeometry(type: .point, coordinates: currentPoints[0])
        case .area:
            let finalPoints = closePolygon(currentPoints)
            geometry = GeoJSONGeometry(type: .polygon, coordinates: [finalPoints])
        default:
            geometry = GeoJSONGeometry(type: .lineString, coordinates: currentPoints)
        }

        let newFeature = GeoJSONFeature(
            properties: properties,
            geometry: geometry
        )

        layers.append(LayerState(feature: newFeature))
        currentPoints = []
        isDrawing = false
    }

    private func closePolygon(_ points: [[Double]]) -> [[Double]] {
        var closedPoints = points
        // If the polygon isn't already closed, close it by adding the first point at the end
        if points.first != points.last {
            closedPoints.append(points[0])
        }
        return closedPoints
    }

    private func deleteSelectedFeatures() {
        layers.removeAll { selectedFeatures.contains($0.id) }
        selectedFeatures.removeAll()
    }
}
