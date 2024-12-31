//
//  DrawingControls.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

enum DrawingMode {
    case lineString
    case point
    case polygon
    case selection
}

struct DrawingControls: View {
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var layers: [LayerState]
    @Binding var selectedFeatures: Set<UUID>
    let selectedFeatureType: TrackFeatureType

    // Add drawing mode state
    @State private var drawingMode: DrawingMode = .lineString
    
    var body: some View {
        VStack {
            // Add mode picker
            Picker("Drawing Mode", selection: $drawingMode) {
                Text("Line").tag(DrawingMode.lineString)
                Text("Point").tag(DrawingMode.point)
                Text("Polygon").tag(DrawingMode.polygon)
                Text("Select").tag(DrawingMode.selection)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Your existing buttons with updated logic
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
    }
    
    private func startNewFeature() {
        isDrawing = true
        currentPoints = []
    }

    private func finishDrawing() {
        // Check minimum points for each type
        let minPoints: Int = {
            switch drawingMode {
            case .point: return 1
            case .lineString: return 2
            case .polygon: return 3
            case .selection: return 0
            }
        }()
        
        guard currentPoints.count >= minPoints else { return }

        let properties: [String: PropertyValue] = [
            "id": .string("\(selectedFeatureType.rawValue)-\(UUID().uuidString)"),
            "name": .string("New \(selectedFeatureType.rawValue.capitalized)")
        ]
        
        // Create appropriate geometry type
        let geometry: GeoJSONGeometry = {
            switch drawingMode {
            case .point:
                return GeoJSONGeometry(point: currentPoints[0])
                
            case .lineString:
                return GeoJSONGeometry(lineString: currentPoints)
                
            case .polygon:
                // Close the polygon if needed
                var polygonPoints = currentPoints
                if polygonPoints.first != polygonPoints.last {
                    polygonPoints.append(polygonPoints[0])
                }
                return GeoJSONGeometry(polygon: [polygonPoints])
                
            case .selection:
                // Default to LineString if somehow we get here
                return GeoJSONGeometry(lineString: currentPoints)
            }
        }()
        
        // Create feature with proper geometry
        let newFeature = GeoJSONFeature(
            properties: properties,
            geometry: geometry
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
