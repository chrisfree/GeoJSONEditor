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

    func calculateFeatureBounds(feature: GeoJSONFeature) -> MKMapRect? {
        guard let geometry = feature.geometry else { return nil }
        var coordinates: [[Double]] = []
        
        switch geometry.type {
        case .point:
            if let point = geometry.pointCoordinates {
                coordinates = [point]
            }
        case .multiPoint:
            coordinates = geometry.multiPointCoordinates ?? []
        case .lineString:
            coordinates = geometry.lineStringCoordinates ?? []
        case .multiLineString:
            coordinates = geometry.multiLineStringCoordinates?.flatMap { $0 } ?? []
        case .polygon:
            coordinates = geometry.polygonCoordinates?.flatMap { $0 } ?? []
        case .multiPolygon:
            coordinates = geometry.multiPolygonCoordinates?.flatMap { $0.flatMap { $0 } } ?? []
        case .geometryCollection:
            if let firstGeometry = geometry.geometryCollectionGeometries?.first {
                let dummyFeature = GeoJSONFeature(properties: nil, geometry: firstGeometry)
                return calculateFeatureBounds(feature: dummyFeature)
            }
        }
        
        guard !coordinates.isEmpty else { return nil }
        
        // Convert coordinates to map points and create a bounding rect
        let points = coordinates.map { coord -> MKMapPoint in
            let location = CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            return MKMapPoint(location)
        }
        
        let rect = points.reduce(MKMapRect.null) { rect, point in
            let pointRect = MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0))
            return rect.isNull ? pointRect : rect.union(pointRect)
        }
        
        return rect
    }

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
        
        // Force updateNSView is called whenever the view needs to be updated
        // This can happen when the view is first loaded, or when the view's state changes
        
        // Force update handling
        if shouldForceUpdate {
            print("Force updating map region to: \(region)")
            DispatchQueue.main.async {
                mapView.setRegion(region, animated: true)
                self.shouldForceUpdate = false
            }
            return // Exit early after force update
        }
        
        // Regular update handling
        if !editingState.isEnabled && context.coordinator.draggedPointIndex == nil {
            let currentRegion = mapView.region
            let significantChange = abs(currentRegion.center.latitude - region.center.latitude) > 0.00001 ||
                                  abs(currentRegion.center.longitude - region.center.longitude) > 0.00001 ||
                                  abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) > 0.00001 ||
                                  abs(currentRegion.span.longitudeDelta - region.span.longitudeDelta) > 0.00001
            
            if significantChange {
                print("Updating region due to significant change")
                mapView.setRegion(region, animated: false)
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
                // Store the editing feature
                context.coordinator.currentEditingFeature = features.first { $0.id == editingId }
                
                if let editingFeature = context.coordinator.currentEditingFeature,
                   let geometry = editingFeature.geometry {
                    
                    // Convert geometry coordinates to CLLocationCoordinate2D
                    var points: [CLLocationCoordinate2D] = []
                    
                    switch geometry.type {
                    case .point:
                        if let coord = geometry.pointCoordinates {
                            points = [CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])]
                        }
                    case .lineString:
                        if let coords = geometry.lineStringCoordinates {
                            points = coords.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                        }
                    case .polygon:
                        if let exteriorRing = geometry.polygonCoordinates?.first {
                            points = exteriorRing.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                        }
                    default:
                        break
                    }
                    
                    // Store current coordinates for editing
                    context.coordinator.currentCoordinates = points
                    
                    // Create overlay for the main shape
                    if let overlay = context.coordinator.createOverlay(from: editingFeature) {
                        if let polyline = overlay as? MKPolyline {
                            context.coordinator.mainPolyline = polyline
                        }
                        mapView.addOverlay(overlay, level: .aboveRoads)
                        
                        // Create point overlays for editing
                        for (index, coordinate) in points.enumerated() {
                            let point = EditablePoint(coordinate: coordinate, index: index)
                            context.coordinator.pointOverlays.append(point)
                            mapView.addOverlay(point, level: .aboveLabels)
                        }
                    }
                }
            } else {
                context.coordinator.currentEditingFeature = nil
                context.coordinator.mainPolyline = nil
            }
            
            // Add background features
            for feature in features where feature.id != editingState.selectedFeatureId {
                if let overlay = context.coordinator.createOverlay(from: feature) {
                    if let polyline = overlay as? MKPolyline {
                        context.coordinator.polylineToFeature[polyline] = feature
                    }
                    mapView.addOverlay(overlay, level: .aboveRoads)
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
        var lastDragUpdate: DispatchWorkItem?

        init(_ parent: MapViewWrapper) {
            self.parent = parent
            super.init()
        }

        func updatePointOverlays(_ mapView: MKMapView) {
            let existingPoints = pointOverlays
            mapView.removeOverlays(existingPoints)
            pointOverlays.removeAll()
            
            // Add new point overlays based on current coordinates
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
                lastDragUpdate?.cancel()
                lastDragUpdate = nil
                
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
                  let editingFeature = currentEditingFeature else {
                print("Debug: No map view or editing feature")
                return
            }
            
            // Cancel any pending updates
            lastDragUpdate?.cancel()
            
            if index < currentCoordinates.count {
                // Update coordinate in array
                currentCoordinates[index] = newCoordinate
                
                if let geometry = editingFeature.geometry {
                    switch geometry.type {
                    case .lineString:
                        // LineString case remains the same as previous optimization
                        let workItem = DispatchWorkItem { [weak self] in
                            guard let self = self else { return }
                            
                            var overlaysToRemove: [MKOverlay] = []
                            var overlaysToAdd: [MKOverlay] = []
                            
                            if let existingPolyline = self.mainPolyline {
                                overlaysToRemove.append(existingPolyline)
                            }
                            let newPolyline = MKPolyline(coordinates: self.currentCoordinates, count: self.currentCoordinates.count)
                            self.mainPolyline = newPolyline
                            overlaysToAdd.append(newPolyline)
                            
                            if index < self.pointOverlays.count {
                                overlaysToRemove.append(self.pointOverlays[index])
                                let point = EditablePoint(coordinate: newCoordinate, index: index)
                                self.pointOverlays[index] = point
                                overlaysToAdd.append(point)
                            }
                            
                            mapView.removeOverlays(overlaysToRemove)
                            mapView.addOverlays(overlaysToAdd, level: .aboveRoads)
                            
                            if let newGeometry = self.updateGeometryCoordinates(newCoordinate, at: index, for: editingFeature),
                               let layerIndex = self.parent.layers.firstIndex(where: { $0.id == editingFeature.id }) {
                                var updatedLayer = self.parent.layers[layerIndex]
                                updatedLayer.feature = GeoJSONFeature(
                                    id: editingFeature.id,
                                    properties: editingFeature.properties,
                                    geometry: newGeometry
                                )
                                self.parent.layers[layerIndex] = updatedLayer
                            }
                        }
                        
                        lastDragUpdate = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0/240.0, execute: workItem)
                        
                    case .polygon:
                        // Optimized polygon case
                        let workItem = DispatchWorkItem { [weak self] in
                            guard let self = self else { return }
                            
                            // Handle first/last point synchronization for polygons
                            if index == 0 || index == self.currentCoordinates.count - 1 {
                                let lastIndex = self.currentCoordinates.count - 1
                                self.currentCoordinates[0] = newCoordinate
                                self.currentCoordinates[lastIndex] = newCoordinate
                            }
                            
                            var overlaysToRemove: [MKOverlay] = []
                            var overlaysToAdd: [MKOverlay] = []
                            
                            // Remove existing polygon overlays
                            overlaysToRemove.append(contentsOf: mapView.overlays.filter { $0 is MKPolygon })
                            
                            // Add new polygon
                            let newPolygon = MKPolygon(coordinates: self.currentCoordinates, count: self.currentCoordinates.count)
                            overlaysToAdd.append(newPolygon)
                            
                            // Handle point overlay
                            if index < self.pointOverlays.count {
                                overlaysToRemove.append(self.pointOverlays[index])
                                let point = EditablePoint(coordinate: newCoordinate, index: index)
                                self.pointOverlays[index] = point
                                overlaysToAdd.append(point)
                            }
                            
                            // Batch update overlays
                            mapView.removeOverlays(overlaysToRemove)
                            mapView.addOverlays(overlaysToAdd, level: .aboveRoads)
                            
                            // Update layer state
                            if let newGeometry = self.updateGeometryCoordinates(newCoordinate, at: index, for: editingFeature),
                               let layerIndex = self.parent.layers.firstIndex(where: { $0.id == editingFeature.id }) {
                                var updatedLayer = self.parent.layers[layerIndex]
                                updatedLayer.feature = GeoJSONFeature(
                                    id: editingFeature.id,
                                    properties: editingFeature.properties,
                                    geometry: newGeometry
                                )
                                self.parent.layers[layerIndex] = updatedLayer
                            }
                        }
                        
                        lastDragUpdate = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0/240.0, execute: workItem)
                        
                    default:
                        break
                    }
                }
                
                parent.editingState.modifiedCoordinates = currentCoordinates.map { coord in
                    [coord.longitude, coord.latitude]
                }
            }
        }

        func updateGeometryCoordinates(_ newCoordinate: CLLocationCoordinate2D, at index: Int, for feature: GeoJSONFeature) -> GeoJSONGeometry? {
            guard let geometry = feature.geometry else { return nil }
            let newPoint = [newCoordinate.longitude, newCoordinate.latitude]
            
            switch geometry.type {
            case .point:
                return GeoJSONGeometry(point: newPoint)
            case .lineString:
                guard var points = geometry.lineStringCoordinates else { return nil }
                guard index < points.count else { return nil }
                points[index] = newPoint
                return GeoJSONGeometry(lineString: points)
            case .polygon:
                guard var polygon = geometry.polygonCoordinates,
                      !polygon.isEmpty,
                      var exteriorRing = polygon.first else { return nil }
                
                if index >= exteriorRing.count { return nil }
                
                exteriorRing[index] = newPoint
                
                if index == 0 || index == exteriorRing.count - 1 {
                    exteriorRing[0] = newPoint
                    exteriorRing[exteriorRing.count - 1] = newPoint
                }
                
                polygon[0] = exteriorRing
                return GeoJSONGeometry(polygon: polygon)
            default:
                return nil
            }
        }

        func createOverlay(from feature: GeoJSONFeature) -> MKOverlay? {
            guard let geometry = feature.geometry else { return nil }
            
            if parent.editingState.isEnabled && feature.id == parent.editingState.selectedFeatureId {
                switch geometry.type {
                case .point:
                    if let coords = geometry.pointCoordinates {
                        let coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
                        return MKCircle(center: coordinate, radius: 10)
                    }
                case .lineString:
                    if let coords = geometry.lineStringCoordinates {
                        let points = coords.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                        return MKPolyline(coordinates: points, count: points.count)
                    }
                case .polygon:
                    if let polygonCoords = geometry.polygonCoordinates {
                        let exteriorRing = polygonCoords[0].map { coord in
                            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                        }
                        return MKPolygon(coordinates: exteriorRing, count: exteriorRing.count)
                    }
                default:
                    break
                }
            } else {
                switch geometry.type {
                case .point:
                    if let coords = geometry.pointCoordinates {
                        let coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
                        return MKCircle(center: coordinate, radius: 10)
                    }
                case .lineString:
                    if let coords = geometry.lineStringCoordinates {
                        let points = coords.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                        return MKPolyline(coordinates: points, count: points.count)
                    }
                case .polygon:
                    if let polygonCoords = geometry.polygonCoordinates {
                        let exteriorRing = polygonCoords[0].map { coord in
                            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                        }
                        return MKPolygon(coordinates: exteriorRing, count: exteriorRing.count)
                    }
                default:
                    break
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
            }
            
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline === mainPolyline {
                    renderer.strokeColor = .systemBlue
                    renderer.lineWidth = 3
                } else if let feature = polylineToFeature[polyline] {
                    renderer.strokeColor = TrackFeatureType.fromFeature(feature).color
                    renderer.lineWidth = 5
                } else {
                    renderer.strokeColor = .systemGray
                    renderer.lineWidth = 5
                }
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                if parent.editingState.isEnabled && parent.editingState.selectedFeatureId != nil {
                    renderer.fillColor = .systemBlue.withAlphaComponent(0.1)
                    renderer.strokeColor = .systemBlue
                    renderer.lineWidth = 2
                } else {
                    renderer.fillColor = .systemGreen.withAlphaComponent(0.2)
                    renderer.strokeColor = .systemGreen
                    renderer.lineWidth = 2
                }
                return renderer
            }
            
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = .systemBlue.withAlphaComponent(0.3)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 2
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if draggedPointIndex == nil {
                updatePointOverlays(mapView)
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            updateOverlaysDuringZoom(mapView)
        }

        func mapViewRegionIsChanging(_ mapView: MKMapView) {
            updateOverlaysDuringZoom(mapView)
        }

        func setupBackgroundFeatures() {
            guard let mapView = self.mapView else { return }

            for (polyline, _) in polylineToFeature {
                mapView.removeOverlay(polyline)
            }
            polylineToFeature.removeAll()

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
            let span = mapView.region.span.longitudeDelta
            let zoomLevel = log2(360.0 / span)
            return min(max(zoomLevel, 0), 20)
        }

        func getPointRadius(for mapView: MKMapView) -> CLLocationDistance {
            let zoomLevel = mapView.zoomLevel

            let baseRadius = 3.5

            let scaleFactor = pow(2.0, 15 - zoomLevel)

            return min(max(baseRadius * scaleFactor, 2), 15)
        }

        func getLineWidth(for zoomLevel: Double) -> CGFloat {
            let baseWidth: CGFloat = 5.0
            let scaleFactor = max(1.0, 15.0 / pow(2, zoomLevel - 10))
            return min(max(baseWidth * scaleFactor, 2), 15)
        }

        func updateOverlaysDuringZoom(_ mapView: MKMapView) {
            if draggedPointIndex == nil {
                updatePointOverlays(mapView)
            }
        }
    }
}
