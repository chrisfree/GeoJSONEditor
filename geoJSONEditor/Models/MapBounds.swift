//
//  MapBounds.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

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
