//
//  EditablePoint.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import MapKit

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
