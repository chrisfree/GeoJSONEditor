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
    var isDraggingPoint: Bool = false  // Add this line
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        // Use a smaller epsilon for more precise matching
        let epsilon: CLLocationDegrees = 0.0000001
        return abs(lhs.latitude - rhs.latitude) < epsilon &&
               abs(lhs.longitude - rhs.longitude) < epsilon
    }
}

struct MapBounds {
    var minLat: Double
    var maxLat: Double
    var minLon: Double
    var maxLon: Double

    init() {
        minLat = Double.infinity
        maxLat = -Double.infinity
        minLon = Double.infinity
        maxLon = -Double.infinity
    }

    init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }

    var isValid: Bool {
        minLat != Double.infinity && maxLat != -Double.infinity &&
        minLon != Double.infinity && maxLon != -Double.infinity
    }

    var center: (lat: Double, lon: Double) {
        ((minLat + maxLat) / 2, (minLon + maxLon) / 2)
    }

    mutating func extend(lat: Double, lon: Double) {
        minLat = min(minLat, lat)
        maxLat = max(maxLat, lat)
        minLon = min(minLon, lon)
        maxLon = max(maxLon, lon)
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


struct MapViewWrapper: NSViewRepresentable {
    let features: [GeoJSONFeature]
    let selectedFeatures: Set<UUID>
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var region: MKCoordinateRegion
    @Binding var editingState: EditingState
    @Binding var shouldForceUpdate: Bool  // Change to binding
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
        // If forcing update or conditions are met, update the region
        if shouldForceUpdate ||
            (!editingState.isEnabled && context.coordinator.draggedPointIndex == nil) {
            
            let currentRegion = mapView.region
            if currentRegion.center.latitude != region.center.latitude ||
                currentRegion.center.longitude != region.center.longitude ||
                currentRegion.span.latitudeDelta != region.span.latitudeDelta ||
                currentRegion.span.longitudeDelta != region.span.longitudeDelta {
                
                print("Updating map region...")
                mapView.setRegion(region, animated: true)
                
                // Reset the force update flag after applying the update
                if shouldForceUpdate {
                    DispatchQueue.main.async {
                        self.shouldForceUpdate = false
                    }
                }
            }
        }

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

        private func findClosestPoint(to location: CGPoint, in mapView: MKMapView) -> (Int, CLLocationCoordinate2D)? {
            let pointsWithIndices = currentCoordinates.enumerated().map { ($0, $1) }
            let closest = pointsWithIndices.min(by: { point1, point2 in
                let point1Screen = mapView.convert(point1.1, toPointTo: mapView)
                let point2Screen = mapView.convert(point2.1, toPointTo: mapView)
                let distance1 = hypot(location.x - point1Screen.x, location.y - point1Screen.y)
                let distance2 = hypot(location.x - point2Screen.x, location.y - point2Screen.y)
                return distance1 < distance2
            })

            if let closest = closest {
                let screenPoint = mapView.convert(closest.1, toPointTo: mapView)
                let distance = hypot(location.x - screenPoint.x, location.y - screenPoint.y)
                return distance <= 20 ? closest : nil
            }
            return nil
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
                // Update drag state when starting drag
                if let closest = findClosestPoint(to: location, in: mapView) {
                    draggedPointIndex = closest.0
                    parent.editingState.isDraggingPoint = true
                    mapView.isScrollEnabled = false
                }

            case .changed:
                if draggedPointIndex != nil {
                    updatePolylineCoordinates(coordinate, at: draggedPointIndex!)
                }

            case .ended, .cancelled:
                if let index = draggedPointIndex {
                    parent.onPointMoved(index, coordinate)
                }
                // Clear drag state
                draggedPointIndex = nil
                parent.editingState.isDraggingPoint = false
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

