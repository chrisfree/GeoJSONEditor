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

// MARK: - Main View
struct MapViewWrapper: NSViewRepresentable {
    @EnvironmentObject private var selectionState: SelectionState
    let features: [GeoJSONFeature]
    let selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    @Binding var isDrawing: Bool
    @Binding var currentPoints: [[Double]]
    @Binding var region: MKCoordinateRegion
    @Binding var editingState: EditingState
    @Binding var shouldForceUpdate: Bool
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
        print("\nUpdating map view...")
        print("Available layers: \(layers.count)")
        print("Available features: \(features.count)")
        
        // Update layers in coordinator
        context.coordinator.updateLayers(layers)
        
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
            context.coordinator.polygonToFeature.removeAll()
            context.coordinator.pointAnnotations.forEach { mapView.removeAnnotation($0) }
            context.coordinator.pointAnnotations.removeAll()

            // Update the currentEditingFeature when in edit mode
            if editingState.isEnabled, let editingId = editingState.selectedFeatureId {
                context.coordinator.currentEditingFeature = features.first { $0.id == editingId }
            } else {
                context.coordinator.currentEditingFeature = nil
            }

            for feature in features {
                print("Processing feature: \(feature.id)")
                if let layer = layers.first(where: { $0.feature.id == feature.id }) {
                    print("Found matching layer with color: \(layer.color)")
                }
                
                switch feature.geometry.type {
                case .point:
                    handlePoint(feature, mapView: mapView, context: context)
                case .lineString:
                    handleLineString(feature, mapView: mapView, context: context)
                case .polygon:
                    handlePolygon(feature, mapView: mapView, context: context)
                default:
                    print("Unsupported geometry type: \(feature.geometry.type)")
                    continue
                }
            }
        }
    }

    private func handlePoint(_ feature: GeoJSONFeature, mapView: MKMapView, context: Context) {
        guard let pointCoords = feature.geometry.pointCoordinates else { return }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: pointCoords[1],
            longitude: pointCoords[0]
        )
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = feature.properties["name"]?.stringValue
        
        context.coordinator.pointAnnotations.append(annotation)
        mapView.addAnnotation(annotation)
    }

    private func handleLineString(_ feature: GeoJSONFeature, mapView: MKMapView, context: Context) {
        guard let lineStringCoords = feature.geometry.lineStringCoordinates else { return }

        let coordinates = lineStringCoords.map {
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

    private func handlePolygon(_ feature: GeoJSONFeature, mapView: MKMapView, context: Context) {
        guard let polygonCoords = feature.geometry.polygonCoordinates,
              !polygonCoords.isEmpty else { return }

        // Convert the outer ring coordinates
        let outerRingCoords = polygonCoords[0].map {
            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        }

        // Create polygon from outer ring
        let polygon = MKPolygon(coordinates: outerRingCoords, count: outerRingCoords.count)

        if editingState.isEnabled && feature.id == editingState.selectedFeatureId {
            context.coordinator.mainPolygon = polygon
            mapView.addOverlay(polygon, level: .aboveRoads)
            context.coordinator.currentCoordinates = outerRingCoords

            for (index, coordinate) in outerRingCoords.enumerated() {
                let point = EditablePoint(coordinate: coordinate, index: index)
                context.coordinator.pointOverlays.append(point)
                mapView.addOverlay(point, level: .aboveLabels)
            }
        } else {
            context.coordinator.polygonToFeature[polygon] = feature
            mapView.addOverlay(polygon, level: .aboveRoads)
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
        var mainPolygon: MKPolygon?
        var pointOverlays: [EditablePoint] = []
        var currentCoordinates: [CLLocationCoordinate2D] = []
        var lastUpdateTime: TimeInterval = 0
        var polylineToFeature: [MKPolyline: GeoJSONFeature] = [:]
        var polygonToFeature: [MKPolygon: GeoJSONFeature] = [:]
        var debounceTimer: Timer?
        let updateInterval: TimeInterval = 1.0 / 60.0
        var pointAnnotations: [MKPointAnnotation] = []
        
        // Change currentLayers to internal access
        var currentLayers: [LayerState] = []
        
        // Track layers by feature ID instead of overlay
        private var featureIdToLayer: [UUID: LayerState] = [:]
        
        // Update layers method
        func updateLayers(_ layers: [LayerState]) {
            self.currentLayers = layers
            // Update feature ID to layer mapping
            featureIdToLayer = Dictionary(uniqueKeysWithValues: layers.map { ($0.feature.id, $0) })
        }
        
        func associateLayer(_ layer: LayerState, withFeatureId id: UUID) {
            featureIdToLayer[id] = layer
        }
        
        func layer(for feature: GeoJSONFeature) -> LayerState? {
            return featureIdToLayer[feature.id]
        }

        init(_ parent: MapViewWrapper) {
            self.parent = parent
            super.init()
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            if parent.editingState.isEnabled {
                let location = gesture.location(in: mapView)
                
                if let (index, _) = findClosestPoint(to: location, in: mapView) {
                    // If clicking the already selected point, deselect it
                    if parent.editingState.selectedPointIndex == index {
                        parent.editingState.selectedPointIndex = nil
                        parent.selectionState.selectedPoints
                            .removeAll(where: { $0 == index })
                    } else {
                        parent.editingState.selectedPointIndex = index
                        parent.selectionState.selectedPoints.append(index)
                    }
                    
                    // Force overlay refresh
                    updatePointOverlays(mapView)
                    return
                }
                
                // If clicking away from points, deselect current point
                if parent.editingState.selectedPointIndex != nil {
                    parent.editingState.selectedPointIndex = nil
                    updatePointOverlays(mapView)
                }
            }

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

            for (polyline, _) in polylineToFeature {
                mapView.removeOverlay(polyline)
            }
            polylineToFeature.removeAll()

            let backgroundFeatures = parent.features.filter { $0.id != parent.editingState.selectedFeatureId }
            for feature in backgroundFeatures {
                guard feature.geometry.type == .lineString,
                      let lineStringCoords = feature.geometry.lineStringCoordinates else {
                    continue
                }

                let coordinates = lineStringCoords.map {
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
                if let closest = findClosestPoint(to: location, in: mapView) {
                    draggedPointIndex = closest.0
                    parent.editingState.selectedPointIndex = closest.0
                    parent.editingState.isDraggingPoint = true
                    mapView.isScrollEnabled = false

                    // Add the selected point to the array if it doesn't already exist
                    if !parent.selectionState.selectedPoints.contains(closest.0) {
                        parent.selectionState.selectedPoints.append(closest.0)
                    }

                    updatePointOverlays(mapView)
                }

            case .changed:
                if let index = draggedPointIndex {
                    updatePolylineCoordinates(coordinate, at: index)
                }

            case .ended, .cancelled:
                if let index = draggedPointIndex {
                    parent.onPointMoved(index, coordinate)
                    draggedPointIndex = nil  // Clear the dragged point index
                }
                parent.editingState.isDraggingPoint = false
                mapView.isScrollEnabled = true
                debounceTimer?.invalidate()
                debounceTimer = nil

            default:
                break
            }
        }

        // Helper method to refresh point overlays
        private func updatePointOverlays(_ mapView: MKMapView) {
            // Remove only existing point overlays
            let existingPoints = pointOverlays
            mapView.removeOverlays(existingPoints)
            pointOverlays.removeAll()

            // Add new point overlays
            for (index, coordinate) in currentCoordinates.enumerated() {
                let point = EditablePoint(coordinate: coordinate, index: index)
                pointOverlays.append(point)
                mapView.addOverlay(point, level: .aboveLabels)
            }
        }

        private func getCurrentZoomLevel(_ mapView: MKMapView) -> Double {
            // Calculate zoom level based on latitude span
            return log2(360 * ((Double(mapView.frame.width) / 256) / mapView.region.span.latitudeDelta)) + 1
        }

        private func getPointRadius(for mapView: MKMapView) -> CLLocationDistance {
            let zoomLevel = mapView.zoomLevel

            // Start with a small base radius in meters
            let baseRadius = 3.5

            // Scale down as we zoom in, up as we zoom out
            let scaleFactor = pow(2.0, 15 - zoomLevel)

            // Clamp the radius between 2 and 10 meters
            return min(max(baseRadius * scaleFactor, 2), 15)
        }

        private func getLineWidth(for zoomLevel: Double) -> CGFloat {
            // Base width is 5 points
            let baseWidth: CGFloat = 5.0
            // Scale factor decreases as zoom level increases
            let scaleFactor = max(1.0, 15.0 / pow(2, zoomLevel - 10))
            // Clamp the final width between 2 and 15 points
            return min(max(baseWidth * scaleFactor, 2), 15)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("\n=== RENDERING OVERLAY ===")
            print("Type: \(type(of: overlay))")
            print("Available layers: \(currentLayers.count)")
            
            if let point = overlay as? EditablePoint {
                return handlePoint(point, mapView: mapView)
            }

            if let polyline = overlay as? MKPolyline {
                print("Rendering Polyline")
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                if polyline === mainPolyline {
                    print("- Main polyline")
                    renderer.strokeColor = .systemBlue
                } else if let feature = polylineToFeature[polyline] {
                    print("- Found feature: \(feature.id)")
                    if let layer = layer(for: feature) {
                        print("- Found layer, using color: \(layer.color)")
                        if let cgColor = layer.color.usingColorSpace(.sRGB)?.cgColor {
                            renderer.strokeColor = NSColor(cgColor: cgColor) ?? .gray
                        }
                    }
                }
                
                renderer.lineWidth = 5
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                print("Rendering Polygon")
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                if polygon === mainPolygon {
                    print("- Main polygon")
                    renderer.fillColor = .systemBlue.withAlphaComponent(0.2)
                    renderer.strokeColor = .systemBlue
                } else if let feature = polygonToFeature[polygon] {
                    print("- Found feature: \(feature.id)")
                    if let layer = layer(for: feature) {
                        print("- Found layer, using color: \(layer.color)")
                        if let cgColor = layer.color.usingColorSpace(.sRGB)?.cgColor {
                            let nsColor = NSColor(cgColor: cgColor) ?? .gray
                            renderer.fillColor = nsColor.withAlphaComponent(0.2)
                            renderer.strokeColor = nsColor
                        }
                    }
                }
                
                renderer.lineWidth = 2
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        private func handlePoint(_ point: EditablePoint, mapView: MKMapView) -> MKOverlayRenderer {
            let radius = getPointRadius(for: mapView)
            let circle = MKCircle(center: point.coordinate, radius: radius)
            let renderer = MKCircleRenderer(circle: circle)

            if parent.selectionState.selectedPoints.contains(point.index) {
                renderer.fillColor = .systemPink
                renderer.strokeColor = .white
            } else {
                renderer.fillColor = .black
                renderer.strokeColor = .white
            }
            renderer.lineWidth = 1.5
            return renderer
        }
        
        // Rest of the code remains the same
    }
}

extension MKMapView {
    var zoomLevel: Double {
        let span = self.region.span.longitudeDelta
        let zoomLevel = log2(360.0 / span)
        return min(max(zoomLevel, 0), 20)
    }
}
