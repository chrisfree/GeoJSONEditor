//
//  F1GeoJSONEditor.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/20/24.
//

import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedFeatures: Set<UUID> = []
    @State private var layers: [LayerState] = []
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.4371, longitude: 5.9714),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var isDrawing = false
    @State private var currentPoints: [[Double]] = []
    @State private var selectedFeatureType: TrackFeatureType = .circuit
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingState = EditingState()
    @State private var lastImportedURL: URL?

    var visibleFeatures: [GeoJSONFeature] {
        layers.filter(\.isVisible).map(\.feature)
    }

    var body: some View {
        HSplitView {
            // Left sidebar with feature list
            FeatureSidebarView(
                selectedFeatures: $selectedFeatures,
                layers: $layers,
                editingState: $editingState,
                selectedFeatureType: $selectedFeatureType,
                isDrawing: $isDrawing,
                currentPoints: $currentPoints
            )
            .frame(minWidth: 200, maxWidth: 300)

            // Main map view
            ZStack {
                MapViewWrapper(
                    features: layers.filter { $0.isVisible }.map { $0.feature },
                    selectedFeatures: selectedFeatures,
                    isDrawing: $isDrawing,
                    currentPoints: $currentPoints,
                    region: $mapRegion,
                    editingState: $editingState,
                    onPointSelected: handlePointSelection,
                    onPointMoved: { index, newCoordinate in
                        handlePointMoved(index: index, newCoordinate: newCoordinate)
                    }
                )
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("GeoJSON"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .toolbar {
            ToolbarItemGroup {
                Button(editingState.isEnabled ? "Exit Edit Mode" : "Edit Mode") {
                    toggleEditMode()
                }
                .disabled(selectedFeatures.isEmpty && !editingState.isEnabled)

                Button("Export GeoJSON") {
                    exportGeoJSON()
                }

                Button("Import GeoJSON") {
                    importGeoJSON()
                }
            }
        }
    }


    private func handlePointMoved(index: Int, newCoordinate: CLLocationCoordinate2D) {
        guard let selectedId = editingState.selectedFeatureId,
              let layerIndex = layers.firstIndex(where: { $0.feature.id == selectedId }) else {
            print("Could not find layer for selected feature")
            return
        }

        // Create new coordinates array
        var newCoords = layers[layerIndex].feature.geometry.coordinates
        guard index < newCoords.count else {
            print("Invalid index for coordinates")
            return
        }

        // Update the coordinate
        newCoords[index] = [newCoordinate.longitude, newCoordinate.latitude]

        // Create updated feature
        var updatedFeature = layers[layerIndex].feature
        updatedFeature.geometry.coordinates = newCoords

        // Update the layer
        layers[layerIndex].feature = updatedFeature

        print("Updated coordinates for point \(index) in feature \(selectedId)")
    }

    private func toggleEditMode() {
        if !editingState.isEnabled {
            // Entering edit mode
            if let selectedFeature = selectedFeatures.first,
               let layerIndex = layers.firstIndex(where: { $0.feature.id == selectedFeature }) {
                print("Entering edit mode with feature: \(selectedFeature)")
                editingState.selectedFeatureId = selectedFeature

                // Hide all layers except the selected one
                for i in 0..<layers.count {
                    layers[i].isVisible = (i == layerIndex)
                }

                print("Set visibility for selected layer at index \(layerIndex)")
            }
        } else {
            // Exiting edit mode
            editingState.selectedFeatureId = nil
            editingState.modifiedCoordinates = nil

            // Restore all layers visibility
            for i in 0..<layers.count {
                layers[i].isVisible = true
            }
        }

        editingState.isEnabled.toggle()
        print("Edit mode is now: \(editingState.isEnabled ? "enabled" : "disabled")")
        print("Selected feature ID: \(editingState.selectedFeatureId?.uuidString ?? "none")")
        print("Visible layers: \(layers.filter(\.isVisible).count)")
    }

    private func binding(for layer: LayerState) -> Binding<Bool> {
        Binding(
            get: { layer.isVisible },
            set: { newValue in
                if let index = layers.firstIndex(where: { $0.id == layer.id }) {
                    layers[index].isVisible = newValue
                }
            }
        )
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
            type: "Feature",
            properties: properties,
            geometry: GeoJSONGeometry(
                type: "LineString",
                coordinates: currentPoints
            )
        )

        layers.append(LayerState(feature: newFeature))
        currentPoints = []
        isDrawing = false
    }

    private func handlePointSelection(_ coordinate: CLLocationCoordinate2D) {
        if isDrawing {
            currentPoints.append([coordinate.longitude, coordinate.latitude])
        }
    }

    private func deleteSelectedFeatures() {
        layers.removeAll { selectedFeatures.contains($0.id) }
        selectedFeatures.removeAll()
    }

    // Then in F1GeoJSONEditor, update the recenterMap function:
    private func recenterMap() {
        print("\n=== RECENTER MAP CALLED ===")
        guard !layers.isEmpty else {
            print("No layers found, exiting recenterMap")
            return
        }

        print("Processing \(layers.count) layers for centering")

        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity

        // Calculate bounds
        for layer in layers {
            for coordinate in layer.feature.geometry.coordinates {
                let lon = coordinate[0]
                let lat = coordinate[1]
                minLat = min(minLat, lat)
                maxLat = max(maxLat, lat)
                minLon = min(minLon, lon)
                maxLon = max(maxLon, lon)
            }
        }

        let latPadding = (maxLat - minLat) * 0.2
        let lonPadding = (maxLon - minLon) * 0.2

        let newCenter = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let newSpan = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) + latPadding,
            longitudeDelta: (maxLon - minLon) + lonPadding
        )

        print("Setting new region - Center: (\(newCenter.latitude), \(newCenter.longitude)), Span: (\(newSpan.latitudeDelta), \(newSpan.longitudeDelta))")

        // Force the update on the main thread
        DispatchQueue.main.async {
            // Create a completely new region instance
            let newRegion = MKCoordinateRegion(
                center: newCenter,
                span: newSpan
            )
            self.mapRegion = newRegion
        }
    }

    private func exportGeoJSON() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "geojson")!]

        if let lastURL = lastImportedURL {
            savePanel.nameFieldStringValue = lastURL.lastPathComponent
            savePanel.directoryURL = lastURL.deletingLastPathComponent()
        } else {
            savePanel.nameFieldStringValue = "track.geojson"
        }

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]

                do {
                    let featureCollection = GeoJSONFeatureCollection(features: layers.map(\.feature))
                    let jsonData = try encoder.encode(featureCollection)

                    // Convert to string to do final formatting adjustments
                    if var jsonString = String(data: jsonData, encoding: .utf8) {
                        // Replace 4 spaces with 2 spaces to match input format
                        jsonString = jsonString.replacingOccurrences(of: "    ", with: "  ")

                        // Ensure consistent newlines
                        jsonString = jsonString.replacingOccurrences(of: "\r\n", with: "\n")

                        // Ensure final newline
                        if !jsonString.hasSuffix("\n") {
                            jsonString += "\n"
                        }

                        try jsonString.write(to: url, atomically: true, encoding: .utf8)

                        alertMessage = "Successfully saved GeoJSON file"
                        showingAlert = true
                    }
                } catch {
                    print("Error saving GeoJSON: \(error)")
                    alertMessage = "Error saving file: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }

    private func importGeoJSON() {
        print("\n=== IMPORT GEOJSON STARTED ===")

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "geojson")!]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            print("Open panel completed with response: \(response == .OK ? "OK" : "Cancel")")

            if response == .OK, let url = openPanel.url {
                print("Selected file: \(url.lastPathComponent)")

                do {
                    let data = try Data(contentsOf: url)
                    print("File data loaded, size: \(data.count) bytes")

                    let decoder = JSONDecoder()
                    let featureCollection = try decoder.decode(GeoJSONFeatureCollection.self, from: data)
                    print("Successfully decoded feature collection with \(featureCollection.features.count) features")

                    DispatchQueue.main.async {
                        print("\nUpdating layers on main thread...")
                        self.layers = featureCollection.features.map { LayerState(feature: $0) }
                        print("Created \(self.layers.count) layer states")

                        print("\nCalling recenterMap...")
                        self.recenterMap()
                        print("recenterMap called")

                        self.lastImportedURL = url
                        self.alertMessage = "Successfully loaded \(self.layers.count) features"
                        self.showingAlert = true
                    }
                } catch {
                    print("Error loading GeoJSON: \(error)")
                    DispatchQueue.main.async {
                        self.alertMessage = "Error loading file: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                }
            }
        }
    }

    private func handlePointMoved(_ index: Int, _ newCoordinate: CLLocationCoordinate2D) {
        guard let featureId = editingState.selectedFeatureId,
              let layerIndex = layers.firstIndex(where: { $0.feature.id == featureId }) else {
            return
        }

        var feature = layers[layerIndex].feature
        var coordinates = feature.geometry.coordinates
        coordinates[index] = [newCoordinate.longitude, newCoordinate.latitude]
        feature.geometry.coordinates = coordinates

        layers[layerIndex].feature = feature
    }

    private func saveEdits() {
        editingState.selectedFeatureId = nil
        editingState.modifiedCoordinates = nil
    }

    private func cancelEdits() {
        if let originalCoordinates = editingState.modifiedCoordinates,
           let featureId = editingState.selectedFeatureId,
           let layerIndex = layers.firstIndex(where: { $0.feature.id == featureId }) {
            var feature = layers[layerIndex].feature
            feature.geometry.coordinates = originalCoordinates
            layers[layerIndex].feature = feature
        }

        editingState.selectedFeatureId = nil
        editingState.modifiedCoordinates = nil
    }
}

struct FeatureSidebarView: View {
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState
    @Binding var selectedFeatureType: TrackFeatureType
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]

    var body: some View {
        VStack {
            FeatureListView(
                selectedFeatures: $selectedFeatures,
                layers: $layers,
                editingState: $editingState
            )

            Divider()

            ControlsView(
                editingState: $editingState,
                selectedFeatureType: $selectedFeatureType,
                isDrawing: $isDrawing,
                currentPoints: $currentPoints,
                layers: $layers,
                selectedFeatures: $selectedFeatures
            )
        }
    }
}

// MARK: - Feature List View
struct FeatureListView: View {
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState  // Changed to @Binding

    var body: some View {
        List(selection: $selectedFeatures) {
            ForEach(layers) { layer in
                FeatureRowView(layer: layer,
                               layers: $layers,
                               editingState: $editingState)  // Pass binding
            }
        }
        .onChange(of: selectedFeatures) { newSelection in
            handleSelectionChange(newSelection)
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

// MARK: - Feature Row View
struct FeatureRowView: View {
    let layer: LayerState
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showingDeleteAlert: Bool = false

    var body: some View {
        HStack {
            VisibilityButton(layer: layer, layers: $layers)

            if isEditingName {
                TextField("Feature Name",
                          text: $editedName,
                          onCommit: {
                    updateFeatureName(editedName)
                    isEditingName = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(layer.feature.properties["name"]?.stringValue ??
                     layer.feature.properties["Name"]?.stringValue ??
                     "Unnamed Feature")
            }

            Spacer()

            if editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id {
                Text("Editing")
                    .foregroundColor(.blue)
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
        .padding(.vertical, 2)
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
        let currentName = layer.feature.properties["name"]?.stringValue ??
        layer.feature.properties["Name"]?.stringValue ??
        "Unnamed Feature"

        // Create a copy of the feature
        var duplicatedFeature = layer.feature

        // Generate a new UUID
        duplicatedFeature.id = UUID()

        // Update properties with new name
        var newProperties = duplicatedFeature.properties
        newProperties["name"] = .string("\(currentName) copy")
        duplicatedFeature.properties = newProperties

        // Create a new LayerState with the duplicated feature
        var newLayer = LayerState(feature: duplicatedFeature)

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
            var properties = updatedFeature.properties
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
}

// MARK: - Custom Button Styles
struct HoverButtonStyle: ButtonStyle {
    var isEditing: Bool = false

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isEditing ? NSColor.systemBlue.asColor :
                    isHovering ? NSColor.labelColor.asColor :
                    NSColor.secondaryLabelColor.asColor
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct HoverDeleteButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isHovering ? NSColor.systemRed.asColor :
                    NSColor.secondaryLabelColor.asColor
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// MARK: - Visibility Button
struct VisibilityButton: View {
    let layer: LayerState
    @Binding var layers: [LayerState]
    @State private var isHovering = false

    private var isVisible: Binding<Bool> {
        Binding(
            get: { layer.isVisible },
            set: { newValue in
                if let index = layers.firstIndex(where: { $0.id == layer.id }) {
                    layers[index].isVisible = newValue
                }
            }
        )
    }

    var body: some View {
        Button(action: {
            isVisible.wrappedValue.toggle()
        }) {
            Image(systemName: isVisible.wrappedValue ? "eye" : "eye.slash")
                .imageScale(.small)
                .foregroundColor(
                    isVisible.wrappedValue ?
                        NSColor.labelColor.asColor :
                        isHovering ?
                            NSColor.labelColor.asColor :
                            NSColor.secondaryLabelColor.asColor
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .help(isVisible.wrappedValue ? "Hide" : "Show")
    }
}

extension NSColor {
    var asColor: Color {
        Color(self)
    }
}

// MARK: - Controls View
struct ControlsView: View {
    @Binding var editingState: EditingState
    @Binding var selectedFeatureType: TrackFeatureType
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var layers: [LayerState]
    @Binding var selectedFeatures: Set<UUID>

    var body: some View {
        VStack(spacing: 10) {
            if !editingState.isEnabled {
                FeatureTypePicker(selectedFeatureType: $selectedFeatureType)
                DrawingControls(
                    isDrawing: $isDrawing,
                    currentPoints: $currentPoints,
                    layers: $layers,
                    selectedFeatures: $selectedFeatures,
                    selectedFeatureType: selectedFeatureType
                )
            }
        }
        .padding()
    }
}

// MARK: - Feature Type Picker
struct FeatureTypePicker: View {
    @Binding var selectedFeatureType: TrackFeatureType

    var body: some View {
        Picker("Feature Type", selection: $selectedFeatureType) {
            Text("Circuit").tag(TrackFeatureType.circuit)
            Text("Sector 1").tag(TrackFeatureType.sectorOne)
            Text("Sector 2").tag(TrackFeatureType.sectorTwo)
            Text("Sector 3").tag(TrackFeatureType.sectorThree)
            Text("DRS Zone").tag(TrackFeatureType.drsZone)
        }
        .pickerStyle(.automatic)
    }
}

// MARK: - Drawing Controls
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
            type: "Feature",
            properties: properties,
            geometry: GeoJSONGeometry(
                type: "LineString",
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
