//
//  PointAnnotation.swift
//  GeoSmith
//

import MapKit

class PointAnnotation: MKPointAnnotation {
    let featureId: UUID
    var isSelected: Bool
    
    init(coordinate: CLLocationCoordinate2D, featureId: UUID, isSelected: Bool = false) {
        self.featureId = featureId
        self.isSelected = isSelected
        super.init()
        self.coordinate = coordinate
    }
}
