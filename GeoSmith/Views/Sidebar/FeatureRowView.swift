//
//  FeatureRowView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI
import MapKit

struct FeatureRowView: View {
    @EnvironmentObject private var selectionState: SelectionState
    let layer: LayerState
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState
    @Binding var region: MKCoordinateRegion
    @Binding var shouldForceUpdate: Bool
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showingDeleteAlert: Bool = false
    @State private var isShowingPoints: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private var featureName: String {
        guard let properties = layer.feature.properties else {
            return "Unnamed Feature"
        }
        
        if let name = properties["name"]?.stringValue {
            return name
        }
        if let name = properties["Name"]?.stringValue {
            return name
        }
        return "Unnamed Feature"
    }
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isShowingPoints,
            content: {
                if let geometry = layer.feature.geometry {
                    FeaturePointsView(
                        layerId: layer.id,
                        editingState: $editingState,
                        layers: $layers
                    )
                    .selectionDisabled()
                }
            },
            label: {
                HStack {
                    VisibilityButton(layer: layer, layers: $layers)

                    if isEditingName {
                        TextField("Feature Name", text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onAppear {
                                isTextFieldFocused = true
                            }
                            .onSubmit {
                                updateFeatureName(editedName)
                                isEditingName = false
                            }
                            .onExitCommand { // Handle escape key
                                isEditingName = false
                            }
                    } else {
                        Text(featureName)
                            .onTapGesture(count: 2) { // Handle double click/tap
                                editedName = featureName
                                isEditingName = true
                                // Delay focus to ensure view is ready
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                        }
                    }

                    Spacer()

                    if editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id {
                        Text("Editing")
                            .foregroundColor(.primary)
                    }

                    Group {
                        // Edit Button
                        Button(action: {
                            toggleEditMode()
                        }) {
                            Image(systemName: "pencil")
                                .imageScale(.small)
                        }
                        .buttonStyle(HoverButtonStyle(isEditing: editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id))
                        .help(editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id
                              ? "Exit Edit Mode"
                              : "Edit Feature")

                        // Duplicate Button
                        Button(action: {
                            duplicateFeature()
                        }) {
                            Image(systemName: "plus.square.on.square")
                                .imageScale(.small)
                        }
                        .buttonStyle(HoverButtonStyle())
                        .help("Duplicate Feature")

                        // Delete Button
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .imageScale(.small)
                        }
                        .buttonStyle(HoverDeleteButtonStyle())
                        .help("Delete Feature")
                    }
                }
                .padding(.leading)
                .contentShape(Rectangle())
                .overlay(
                    Button(action: centerMapOnFeature) {
                        Color.clear
                    }
                    .buttonStyle(.plain)
                )
            }
        )
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Feature"),
                message: Text("Are you sure you want to delete this feature? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteFeature()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func deleteFeature() {
        // If we're deleting the feature being edited, exit edit mode
        if editingState.isEnabled && editingState.selectedFeatureId == layer.id {
            editingState.isEnabled = false
            editingState.selectedFeatureId = nil
            editingState.modifiedCoordinates = nil
        }

        // Remove the layer
        layers.removeAll { $0.id == layer.id }

        // After deletion, make all remaining layers visible
        for i in 0..<layers.count {
            layers[i].isVisible = true
        }
    }

    private func duplicateFeature() {
        // Get the current name of the feature
        let currentName = featureName

        // Create a copy of the feature
        var duplicatedFeature = layer.feature

        // Generate a new UUID
        duplicatedFeature.id = UUID()

        // Update properties with new name
        var newProperties = duplicatedFeature.properties ?? [:]
        newProperties["name"] = .string("\(currentName) copy")
        duplicatedFeature.properties = newProperties

        // Create a new LayerState with the duplicated feature
        let newLayer = LayerState(feature: duplicatedFeature)

        // Add the new layer to the layers array
        layers.append(newLayer)

        // Set up name editing for the new feature
        editedName = "\(currentName) copy"
        isEditingName = true

        // Select and enter edit mode for the new feature
        editingState.isEnabled = true
        editingState.selectedFeatureId = duplicatedFeature.id

        // Update visibility
        for i in 0..<layers.count {
            layers[i].isVisible = (layers[i].feature.id == duplicatedFeature.id)
        }
    }

    private func updateFeatureName(_ newName: String) {
        if let index = layers.firstIndex(where: { $0.id == layer.id }) {
            var updatedFeature = layers[index].feature
            var properties = updatedFeature.properties ?? [:]
            properties["name"] = .string(newName)
            updatedFeature.properties = properties
            layers[index].feature = updatedFeature
        }
    }

    private func toggleEditMode() {
        if editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id {
            // Exiting edit mode
            editingState.isEnabled = false
            editingState.selectedFeatureId = nil
            editingState.modifiedCoordinates = nil

            // Restore all layers visibility
            for i in 0..<layers.count {
                layers[i].isVisible = true
            }
        } else {
            // Entering edit mode
            editingState.isEnabled = true
            editingState.selectedFeatureId = layer.feature.id

            // Hide all layers except the selected one
            for i in 0..<layers.count {
                layers[i].isVisible = (layers[i].feature.id == layer.feature.id)
            }
        }
    }

    private func centerMapOnFeature() {
        print("Centering map on feature: \(layer.feature.id)")
        guard let geometry = layer.feature.geometry else { return }
        
        // Extract coordinates based on geometry type
        var coordinates: [[Double]] = []
        switch geometry.type {
        case .point:
            if let point = geometry.pointCoordinates {
                coordinates = [point]
                print("Point coordinates: \(point)")
            }
        case .multiPoint:
            coordinates = geometry.multiPointCoordinates ?? []
        case .lineString:
            coordinates = geometry.lineStringCoordinates ?? []
        case .multiLineString:
            coordinates = geometry.multiLineStringCoordinates?.flatMap { $0 } ?? []
        case .polygon:
            if let polygonCoords = geometry.polygonCoordinates {
                // Include all rings for better bounds calculation
                coordinates = polygonCoords.flatMap { $0 }
                print("Polygon coordinates count: \(coordinates.count)")
            }
        case .multiPolygon:
            if let multiPolygon = geometry.multiPolygonCoordinates {
                coordinates = multiPolygon.flatMap { $0.flatMap { $0 } }
            }
        case .geometryCollection:
            if let firstGeometry = geometry.geometryCollectionGeometries?.first {
                coordinates = getAllCoordinates(from: firstGeometry)
            }
        }
        
        guard !coordinates.isEmpty else {
            print("No coordinates found")
            return
        }
        
        print("Processing \(coordinates.count) coordinates")
        
        // Calculate bounds
        let lats = coordinates.map { $0[1] }
        let lons = coordinates.map { $0[0] }
        
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        
        print("Bounds - Lat: [\(minLat), \(maxLat)], Lon: [\(minLon), \(maxLon)]")
        
        // Add padding based on geometry type
        let paddingFactor: Double
        switch geometry.type {
        case .point:
            paddingFactor = 0.01 // 1% padding for points
        case .polygon, .multiPolygon:
            paddingFactor = 0.1  // 10% padding for polygons
        default:
            paddingFactor = 0.2  // 20% padding for other types
        }
        
        let latSpan = max(maxLat - minLat, 0.01) // Minimum span of 0.01 degrees
        let lonSpan = max(maxLon - minLon, 0.01)
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: latSpan * (1 + paddingFactor),
            longitudeDelta: lonSpan * (1 + paddingFactor)
        )
        
        print("Setting new region - center: \(center), span: \(span)")
        
        // Update the region and force refresh
        region = MKCoordinateRegion(center: center, span: span)
        DispatchQueue.main.async {
            self.shouldForceUpdate = true
        }
    }
    
    private func getAllCoordinates(from geometry: GeoJSONGeometry) -> [[Double]] {
        switch geometry.type {
        case .point:
            return geometry.pointCoordinates.map { [$0] } ?? []
        case .multiPoint:
            return geometry.multiPointCoordinates ?? []
        case .lineString:
            return geometry.lineStringCoordinates ?? []
        case .multiLineString:
            return geometry.multiLineStringCoordinates?.flatMap { $0 } ?? []
        case .polygon:
            return geometry.polygonCoordinates?.flatMap { $0 } ?? []
        case .multiPolygon:
            return geometry.multiPolygonCoordinates?.flatMap { $0.flatMap { $0 } } ?? []
        case .geometryCollection:
            return geometry.geometryCollectionGeometries?.first.map { getAllCoordinates(from: $0) } ?? []
        }
    }

    // Rest of the implementation remains the same
}
