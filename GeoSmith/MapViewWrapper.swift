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

// MARK: - Map View Extension for Zoom Level
extension MKMapView {
    var zoomLevel: Double {
        let span = self.region.span.longitudeDelta
        let zoomLevel = log2(360.0 / span)
        return min(max(zoomLevel, 0), 20)
    }
}

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
        print("\nSelected Points: \(selectionState.selectedPoints)")
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
                if let overlay = context.coordinator.createOverlay(from: feature) {
                    if editingState.isEnabled && feature.id == editingState.selectedFeatureId {
                        context.coordinator.mainPolyline = overlay as? MKPolyline
                        mapView.addOverlay(overlay, level: .aboveRoads)
                        
                        if let polyline = overlay as? MKPolyline {
                            // Convert polyline coordinates to array
                            var coords = [CLLocationCoordinate2D]()
                            polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
                            context.coordinator.currentCoordinates = coords
                            
                            // Create point overlays
                            for (index, coordinate) in coords.enumerated() {
                                let point = EditablePoint(coordinate: coordinate, index: index)
                                context.coordinator.pointOverlays.append(point)
                                mapView.addOverlay(point, level: .aboveLabels)
                            }
                        }
                    } else {
                        context.coordinator.polylineToFeature[overlay as? MKPolyline ?? MKPolyline()] = feature
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }
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

        func updatePointOverlays(_ mapView: MKMapView) {
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

        func updatePolylineCoordinates(_ newCoordinate: CLLocationCoordinate2D, at index: Int) {
            guard let mapView = self.mapView,
                  let editingFeature = currentEditingFeature else { return }
            
            let currentTime = CACurrentMediaTime()
            guard (currentTime - lastUpdateTime) >= updateInterval else { return }
            lastUpdateTime = currentTime
            
            // Update coordinates in currentCoordinates for display
            currentCoordinates[index] = newCoordinate
            
            // Update the geometry
            if let newGeometry = updateGeometryCoordinates(newCoordinate, at: index, for: editingFeature) {
                // Update the overlay
                if let oldPolyline = mainPolyline {
                    mapView.removeOverlay(oldPolyline)
                }
                
                if let newOverlay = createOverlay(from: GeoJSONFeature(properties: editingFeature.properties, geometry: newGeometry)) {
                    mainPolyline = newOverlay as? MKPolyline
                    mapView.addOverlay(newOverlay, level: .aboveRoads)
                }
                
                // Update point overlay
                if let point = pointOverlays[safe: index] {
                    mapView.removeOverlay(point)
                    let newPoint = EditablePoint(coordinate: newCoordinate, index: index)
                    pointOverlays[index] = newPoint
                    mapView.addOverlay(newPoint, level: .aboveLabels)
                }
                
                // Notify parent of the change
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.parent.onPointMoved(index, newCoordinate)
                }
            }
        }

        func updateGeometryCoordinates(_ newCoordinate: CLLocationCoordinate2D, at index: Int, for feature: GeoJSONFeature) -> GeoJSONGeometry? {
            guard let geometry = feature.geometry else { return nil }
            
            let newPoint = [newCoordinate.longitude, newCoordinate.latitude]
            
            switch geometry.type {
            case .point:
                return GeoJSONGeometry(point: newPoint)
                
            case .multiPoint:
                guard var points = geometry.multiPointCoordinates else { return nil }
                guard index < points.count else { return nil }
                points[index] = newPoint
                return GeoJSONGeometry(multiPoint: points)
                
            case .lineString:
                guard var points = geometry.lineStringCoordinates else { return nil }
                guard index < points.count else { return nil }
                points[index] = newPoint
                return GeoJSONGeometry(lineString: points)
                
            case .multiLineString:
                guard var multiLine = geometry.multiLineStringCoordinates else { return nil }
                // For now, assume we're editing the first linestring
                guard var points = multiLine.first,
                      index < points.count else { return nil }
                points[index] = newPoint
                multiLine[0] = points
                return GeoJSONGeometry(multiLineString: multiLine)
                
            case .polygon:
                guard var polygon = geometry.polygonCoordinates else { return nil }
                // Assume editing exterior ring
                guard var points = polygon.first,
                      index < points.count else { return nil }
                points[index] = newPoint
                polygon[0] = points
                return GeoJSONGeometry(polygon: polygon)
                
            case .multiPolygon:
                guard var multiPolygon = geometry.multiPolygonCoordinates else { return nil }
                // Assume editing first polygon's exterior ring
                guard var polygon = multiPolygon.first,
                      var points = polygon.first,
                      index < points.count else { return nil }
                points[index] = newPoint
                polygon[0] = points
                multiPolygon[0] = polygon
                return GeoJSONGeometry(multiPolygon: multiPolygon)
                
            case .geometryCollection:
                // For now, don't support editing geometry collections
                return nil
            }
        }

        func createOverlay(from feature: GeoJSONFeature) -> MKOverlay? {
            guard let geometry = feature.geometry else { return nil }
            
            switch geometry.type {
            case .point:
                if let coords = geometry.pointCoordinates {
                    let coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
                    return MKCircle(center: coordinate, radius: 10)
                }
                
            case .multiPoint:
                if let coords = geometry.multiPointCoordinates {
                    let points = coords.map { coord in
                        CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    }
                    // Create a circle for the first point as a representation
                    let coordinate = points[0]
                    return MKCircle(center: coordinate, radius: 10)
                }
                
            case .lineString:
                if let coords = geometry.lineStringCoordinates {
                    let points = coords.map { coord in
                        CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    }
                    return MKPolyline(coordinates: points, count: points.count)
                }
                
            case .multiLineString:
                if let multiLine = geometry.multiLineStringCoordinates {
                    let overlays = multiLine.compactMap { coords -> MKPolyline? in
                        let points = coords.map { coord in
                            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                        }
                        return MKPolyline(coordinates: points, count: points.count)
                    }
                    // Return first polyline for now, later we can handle multiple
                    return overlays.first
                }
                
            case .polygon:
                if let polygonCoords = geometry.polygonCoordinates {
                    // First array is exterior ring, rest are holes
                    let exteriorRing = polygonCoords[0].map { coord in
                        CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    }
                    return MKPolygon(coordinates: exteriorRing, count: exteriorRing.count)
                }
                
            case .multiPolygon:
                if let multiPolygon = geometry.multiPolygonCoordinates {
                    let overlays = multiPolygon.compactMap { polygon -> MKPolygon? in
                        let exteriorRing = polygon[0].map { coord in
                            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                        }
                        return MKPolygon(coordinates: exteriorRing, count: exteriorRing.count)
                    }
                    // Return first polygon for now, later we can handle multiple
                    return overlays.first
                }
                
            case .geometryCollection:
                if let geometries = geometry.geometryCollectionGeometries {
                    // For now, just return the first valid geometry's overlay
                    let dummyFeature = GeoJSONFeature(properties: nil, geometry: geometries[0])
                    return createOverlay(from: dummyFeature)
                }
            }
            
            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let point = overlay as? EditablePoint {
                let radius = getPointRadius(for: mapView)
                let circle = MKCircle(center: point.coordinate, radius: radius)
                let renderer = MKCircleRenderer(circle: circle)

                if parent.selectionState.selectedPoints.contains(point.index) {
                    renderer.fillColor = .systemPink
                    renderer.strokeColor = .white
                    renderer.lineWidth = 1.5
                } else {
                    renderer.fillColor = .black
                    renderer.strokeColor = .white
                    renderer.lineWidth = 1.75
                }

                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                if polyline === mainPolyline {
                    renderer.strokeColor = .systemBlue
                } else if let feature = polylineToFeature[polyline] {
                    renderer.strokeColor = TrackFeatureType.fromFeature(feature).color
                } else {
                    renderer.strokeColor = .systemGray
                }

                // Fixed line width - no need to scale this with zoom
                renderer.lineWidth = 5

                return renderer
            }
            
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = .systemBlue.withAlphaComponent(0.3)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 2
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = .systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = .systemGreen
                renderer.lineWidth = 2
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Only update if we're not dragging a point
            if draggedPointIndex == nil {
                // Just update the point overlays
                updatePointOverlays(mapView)
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Called when zoom/pan starts
            updateOverlaysDuringZoom(mapView)
        }

        func mapViewRegionIsChanging(_ mapView: MKMapView) {
            // Called continuously during zoom/pan
            updateOverlaysDuringZoom(mapView)
        }

        func setupBackgroundFeatures() {
            guard let mapView = self.mapView else { return }

            // Clear existing features
            for (polyline, _) in polylineToFeature {
                mapView.removeOverlay(polyline)
            }
            polylineToFeature.removeAll()

            // Add non-editing features
            let backgroundFeatures = parent.features.filter { $0.id != parent.editingState.selectedFeatureId }
            for feature in backgroundFeatures {
                if let overlay = createOverlay(from: feature) {
                    polylineToFeature[overlay as? MKPolyline ?? MKPolyline(coordinates: [], count: 0)] = feature
                    mapView.addOverlay(overlay, level: .aboveRoads)
                }
            }
        }

        func findClosestPoint(to location: CGPoint, in mapView: MKMapView) -> (Int, CLLocationCoordinate2D)? {
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
        
        func getCurrentZoomLevel(_ mapView: MKMapView) -> Double {
            // Calculate zoom level based on latitude span
            return log2(360 * ((Double(mapView.frame.width) / 256) / mapView.region.span.latitudeDelta)) + 1
        }

        func getPointRadius(for mapView: MKMapView) -> CLLocationDistance {
            let zoomLevel = mapView.zoomLevel

            // Start with a small base radius in meters
            let baseRadius = 3.5

            // Scale down as we zoom in, up as we zoom out
            let scaleFactor = pow(2.0, 15 - zoomLevel)

            // Clamp the radius between 2 and 10 meters
            return min(max(baseRadius * scaleFactor, 2), 15)
        }

        func getLineWidth(for zoomLevel: Double) -> CGFloat {
            // Base width is 5 points
            let baseWidth: CGFloat = 5.0
            // Scale factor decreases as zoom level increases
            let scaleFactor = max(1.0, 15.0 / pow(2, zoomLevel - 10))
            // Clamp the final width between 2 and 15 points
            return min(max(baseWidth * scaleFactor, 2), 15)
        }

        func updateOverlaysDuringZoom(_ mapView: MKMapView) {
            // Only update if we're not dragging a point
            if draggedPointIndex == nil {
                updatePointOverlays(mapView)
            }
        }
    }
}
