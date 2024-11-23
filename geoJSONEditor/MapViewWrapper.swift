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
            guard let mapView = gesture.view as? MKMapView else { return }
            
            if parent.editingState.isEnabled {
                let location = gesture.location(in: mapView)
                
                if let (index, _) = findClosestPoint(to: location, in: mapView) {
                    // If clicking the already selected point, deselect it
                    if parent.editingState.selectedPointIndex == index {
                        parent.editingState.selectedPointIndex = nil
                    } else {
                        parent.editingState.selectedPointIndex = index
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
