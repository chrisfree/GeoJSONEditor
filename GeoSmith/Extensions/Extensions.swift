//
//  File.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI
import MapKit

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

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        // Use a smaller epsilon for more precise matching
        let epsilon: CLLocationDegrees = 0.0000001
        return abs(lhs.latitude - rhs.latitude) < epsilon &&
               abs(lhs.longitude - rhs.longitude) < epsilon
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

extension NSColor {
    var asColor: Color {
        Color(self)
    }
    
    // Add conversion to UIColor/NSColor for MKOverlayRenderer
    var mapColor: NSColor {
        // Convert to RGB color space if needed
        guard let rgbColor = usingColorSpace(.sRGB) else { return self }
        return rgbColor
    }
}
