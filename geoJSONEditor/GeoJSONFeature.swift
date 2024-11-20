//
//  GeoJSONFeature.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/16/24.
//

//
//  GeoJSONFeature.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/16/24.
//

import SwiftUI
import MapKit
import UniformTypeIdentifiers

// MARK: - Data Models
enum TrackFeatureType: String {
    case circuit = "circuit"
    case sectorOne = "sector1"
    case sectorTwo = "sector2"
    case sectorThree = "sector3"
    case drsZone = "drs"

    static func fromFeature(_ feature: GeoJSONFeature) -> TrackFeatureType {
        if let id = feature.properties["id"]?.stringValue {
            switch id {
            case "sector1":
                return .sectorOne
            case "sector2":
                return .sectorTwo
            case "sector3":
                return .sectorThree
            case _ where id.contains("be-"):
                return .circuit
            default:
                // If it's not a sector, check if it's a circuit by looking at other properties
                if feature.properties["Location"] != nil ||
                   feature.properties["length"] != nil {
                    return .circuit
                }
                return .drsZone
            }
        }
        return .circuit // Default to circuit if no id found
    }

    var color: NSColor {
        switch self {
        case .circuit:
            return .systemPurple
        case .sectorOne:
            return .systemRed
        case .sectorTwo:
            return .systemTeal
        case .sectorThree:
            return .systemYellow
        case .drsZone:
            return .systemGreen
        }
    }
}

struct GeoJSONFeature: Identifiable, Codable {
    var id: UUID
    var type: String
    var properties: [String: PropertyValue]
    var geometry: GeoJSONGeometry

    enum CodingKeys: String, CodingKey {
        case type, properties, geometry
    }

    init(id: UUID = UUID(), type: String, properties: [String: PropertyValue], geometry: GeoJSONGeometry) {
        self.id = id
        self.type = type
        self.properties = properties
        self.geometry = geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        properties = try container.decode([String: PropertyValue].self, forKey: .properties)
        geometry = try container.decode(GeoJSONGeometry.self, forKey: .geometry)
        id = UUID()
    }
}

enum PropertyValue: Codable {
    case string(String)
    case number(Double)
    case integer(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .integer(let value): return String(value)
        }
    }
}

struct LayerState: Identifiable {
    let id: UUID
    var feature: GeoJSONFeature
    var isVisible: Bool

    init(feature: GeoJSONFeature, isVisible: Bool = true) {
        self.id = feature.id
        self.feature = feature
        self.isVisible = isVisible
    }
}

struct GeoJSONFeatureCollection: Codable {
    var type: String
    var features: [GeoJSONFeature]

    enum CodingKeys: String, CodingKey {
        case type, features
    }

    init(features: [GeoJSONFeature]) {
        self.type = "FeatureCollection"
        self.features = features
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        features = try container.decode([GeoJSONFeature].self, forKey: .features)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(features, forKey: .features)
    }
}

struct GeoJSONGeometry: Codable {
    var type: String
    var coordinates: [[Double]]

    enum CodingKeys: String, CodingKey {
        case coordinates, type
    }

    init(type: String, coordinates: [[Double]]) {
        self.type = type
        self.coordinates = coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coordinates = try container.decode([[Double]].self, forKey: .coordinates)
        type = try container.decode(String.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinates, forKey: .coordinates)
        try container.encode(type, forKey: .type)
    }
}

struct EditingState {
    var isEnabled: Bool = false
    var selectedFeatureId: UUID?
    var modifiedCoordinates: [[Double]]?

    var isEditing: Bool {
        isEnabled && selectedFeatureId != nil
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        // Use a smaller epsilon for more precise matching
        let epsilon: CLLocationDegrees = 0.0000001
        return abs(lhs.latitude - rhs.latitude) < epsilon &&
               abs(lhs.longitude - rhs.longitude) < epsilon
    }
}

// Add helpful extensions for coordinate comparison
extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        let points = self.points()
        for i in 0..<self.pointCount {
            coords.append(points[i].coordinate)
        }
        return coords
    }

    func approximatelyEquals(_ other: [CLLocationCoordinate2D]) -> Bool {
        let coords = self.coordinates()
        guard coords.count == other.count else { return false }

        // Compare a few sample points to save performance while still being accurate
        let sampleSize = min(5, coords.count)
        let strideLength = max(1, coords.count / sampleSize)
        var index = 0

        while index < coords.count {
            if coords[index] != other[index] {
                return false
            }
            index += strideLength
        }
        return true
    }
}

class EditablePoint: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let index: Int
    let radius: CGFloat = 12 // Click target radius in points

    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
        super.init()
    }

    var boundingMapRect: MKMapRect {
        let point = MKMapPoint(coordinate)
        let rect = MKMapRect(
            x: point.x - 1000,
            y: point.y - 1000,
            width: 2000,
            height: 2000
        )
        return rect
    }
}

// MARK: - Main View
struct F1GeoJSONEditor: View {
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
            VStack {
                List(selection: $selectedFeatures) {
                    ForEach(layers) { layer in
                        HStack {
                            Toggle(isOn: binding(for: layer)) {
                                Text(layer.feature.properties["name"]?.stringValue ??
                                     layer.feature.properties["Name"]?.stringValue ??
                                     "Unnamed Feature")
                            }
                            .toggleStyle(CheckboxToggleStyle())

                            if editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id {
                                Text("Editing")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .onChange(of: selectedFeatures) { newSelection in
                    if editingState.isEnabled, let selected = newSelection.first {
                        editingState.selectedFeatureId = selected
                        // Update visibility
                        for i in 0..<layers.count {
                            layers[i].isVisible = layers[i].feature.id == selected
                        }
                    }
                }

                Divider()

                // Controls
                VStack(spacing: 10) {
                    if !editingState.isEnabled {
                        Picker("Feature Type", selection: $selectedFeatureType) {
                            Text("Circuit").tag(TrackFeatureType.circuit)
                            Text("Sector 1").tag(TrackFeatureType.sectorOne)
                            Text("Sector 2").tag(TrackFeatureType.sectorTwo)
                            Text("Sector 3").tag(TrackFeatureType.sectorThree)
                            Text("DRS Zone").tag(TrackFeatureType.drsZone)
                        }
                        .pickerStyle(.automatic)

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
                .padding()
            }
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

struct MapViewWrapper: NSViewRepresentable {
    let features: [GeoJSONFeature]
    let selectedFeatures: Set<UUID>
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var region: MKCoordinateRegion
    @Binding var editingState: EditingState
    let onPointSelected: (CLLocationCoordinate2D) -> Void
    let onPointMoved: (Int, CLLocationCoordinate2D) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        mapView.region = region
        mapView.isZoomEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isScrollEnabled = true

        let dragGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDrag(_:)))
        mapView.addGestureRecognizer(dragGesture)

        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        mapView.addGestureRecognizer(clickGesture)

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Only update region if:
        // 1. We're not in edit mode
        // 2. We're not dragging a point
        // 3. The region has actually changed
        if !editingState.isEnabled &&
           context.coordinator.draggedPointIndex == nil {
            let currentRegion = mapView.region
            if currentRegion.center.latitude != region.center.latitude ||
               currentRegion.center.longitude != region.center.longitude ||
               currentRegion.span.latitudeDelta != region.span.latitudeDelta ||
               currentRegion.span.longitudeDelta != region.span.longitudeDelta {
                mapView.setRegion(region, animated: false)
            }
        }

        // Rest of overlay updates only if not dragging
        if context.coordinator.draggedPointIndex == nil {
            mapView.removeOverlays(mapView.overlays)
            context.coordinator.pointOverlays.removeAll()
            context.coordinator.polylineToFeature.removeAll()

            // Update the currentEditingFeature when in edit mode
            if editingState.isEnabled, let editingId = editingState.selectedFeatureId {
                context.coordinator.currentEditingFeature = features.first { $0.id == editingId }
            } else {
                context.coordinator.currentEditingFeature = nil
            }

            for feature in features {
                let coordinates = feature.geometry.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                }

                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

                if editingState.isEnabled && feature.id == editingState.selectedFeatureId {
                    context.coordinator.mainPolyline = polyline
                    mapView.addOverlay(polyline, level: .aboveRoads)

                    context.coordinator.currentCoordinates = coordinates

                    for (index, coordinate) in coordinates.enumerated() {
                        let point = EditablePoint(coordinate: coordinate, index: index)
                        context.coordinator.pointOverlays.append(point)
                        mapView.addOverlay(point, level: .aboveLabels)
                    }
                } else {
                    context.coordinator.polylineToFeature[polyline] = feature
                    mapView.addOverlay(polyline, level: .aboveRoads)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator class implementation...
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        var draggedPointIndex: Int?
        weak var mapView: MKMapView?
        var currentEditingFeature: GeoJSONFeature?
        var mainPolyline: MKPolyline?
        var pointOverlays: [EditablePoint] = []
        var currentCoordinates: [CLLocationCoordinate2D] = []
        var lastUpdateTime: TimeInterval = 0
        var polylineToFeature: [MKPolyline: GeoJSONFeature] = [:]
        var debounceTimer: Timer?
        let updateInterval: TimeInterval = 1.0 / 60.0

        init(_ parent: MapViewWrapper) {
            self.parent = parent
            super.init()
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard parent.isDrawing,
                  let mapView = gesture.view as? MKMapView else {
                return
            }

            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onPointSelected(coordinate)
        }

        private func updatePolylineCoordinates(_ newCoordinate: CLLocationCoordinate2D, at index: Int) {
            guard let mapView = self.mapView else { return }

            let currentTime = CACurrentMediaTime()
            guard (currentTime - lastUpdateTime) >= updateInterval else { return }
            lastUpdateTime = currentTime

            currentCoordinates[index] = newCoordinate

            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.parent.onPointMoved(index, newCoordinate)
            }

            if let oldPolyline = mainPolyline {
                mapView.removeOverlay(oldPolyline)
            }

            let newPolyline = MKPolyline(coordinates: currentCoordinates, count: currentCoordinates.count)
            mainPolyline = newPolyline

            mapView.addOverlay(newPolyline, level: .aboveRoads)

            if let point = pointOverlays[safe: index] {
                mapView.removeOverlay(point)
                let newPoint = EditablePoint(coordinate: newCoordinate, index: index)
                pointOverlays[index] = newPoint
                mapView.addOverlay(newPoint, level: .aboveLabels)
            }
        }

        private func setupBackgroundFeatures() {
            guard let mapView = self.mapView else { return }

            // Clear existing features
            for (polyline, _) in polylineToFeature {
                mapView.removeOverlay(polyline)
            }
            polylineToFeature.removeAll()

            // Add non-editing features
            let backgroundFeatures = parent.features.filter { $0.id != parent.editingState.selectedFeatureId }
            for feature in backgroundFeatures {
                let coordinates = feature.geometry.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                }
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polylineToFeature[polyline] = feature
                mapView.addOverlay(polyline, level: .aboveRoads)
            }
        }

        @objc func handleDrag(_ gesture: NSPanGestureRecognizer) {
            guard parent.editingState.isEnabled,
                  let mapView = gesture.view as? MKMapView else {
                return
            }

            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

            switch gesture.state {
            case .began:
                if currentCoordinates.isEmpty {
                    currentCoordinates = currentEditingFeature?.geometry.coordinates.map {
                        CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                    } ?? []
                    setupBackgroundFeatures()
                }

                let pointsWithIndices = currentCoordinates.enumerated().map { ($0, $1) }
                if let closest = pointsWithIndices.min(by: { point1, point2 in
                    let point1Screen = mapView.convert(point1.1, toPointTo: mapView)
                    let point2Screen = mapView.convert(point2.1, toPointTo: mapView)
                    let distance1 = hypot(location.x - point1Screen.x, location.y - point1Screen.y)
                    let distance2 = hypot(location.x - point2Screen.x, location.y - point2Screen.y)
                    return distance1 < distance2
                }) {
                    let screenPoint = mapView.convert(closest.1, toPointTo: mapView)
                    let distance = hypot(location.x - screenPoint.x, location.y - screenPoint.y)

                    if distance <= 20 {
                        print("Starting drag on point \(closest.0)")
                        draggedPointIndex = closest.0
                        mapView.isScrollEnabled = false
                    }
                }

            case .changed:
                if let index = draggedPointIndex {
                    print("Dragging point \(index) to \(coordinate)")
                    updatePolylineCoordinates(coordinate, at: index)
                }

            case .ended, .cancelled:
                if let index = draggedPointIndex {
                    print("Finished dragging point \(index)")
                    parent.onPointMoved(index, coordinate)
                }
                draggedPointIndex = nil
                mapView.isScrollEnabled = true
                debounceTimer?.invalidate()
                debounceTimer = nil

            default:
                break
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let point = overlay as? EditablePoint {
                let circle = MKCircle(center: point.coordinate, radius: 2)
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = .orange
                renderer.strokeColor = .white
                renderer.lineWidth = 2
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                if polyline === mainPolyline {
                    renderer.strokeColor = .systemBlue
                } else if let feature = polylineToFeature[polyline] {
                    // Use the feature type's color
                    renderer.strokeColor = TrackFeatureType.fromFeature(feature).color
                } else {
                    renderer.strokeColor = .systemGray
                }

                renderer.lineWidth = 5
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Helper extension for CGPoint distance calculation
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

