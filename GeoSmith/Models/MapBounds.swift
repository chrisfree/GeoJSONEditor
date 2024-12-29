//
//  MapBounds.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

struct MapBounds {
    var minLat: Double = .infinity
    var maxLat: Double = -.infinity
    var minLon: Double = .infinity
    var maxLon: Double = -.infinity

    init() {
        minLat = .infinity
        maxLat = -.infinity
        minLon = .infinity
        maxLon = -.infinity
    }

    init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }

    var isValid: Bool {
        minLat < .infinity && maxLat > -.infinity &&
        minLon < .infinity && maxLon > -.infinity
    }

    var center: (lat: Double, lon: Double) {
        ((maxLat + minLat) / 2, (maxLon + minLon) / 2)
    }

    mutating func extend(lat: Double, lon: Double) {
        guard lat.isFinite && lon.isFinite else { return }
        minLat = min(minLat, lat)
        maxLat = max(maxLat, lat)
        minLon = min(minLon, lon)
        maxLon = max(maxLon, lon)
    }

    mutating func extendWithGeometry(_ geometry: GeoJSONGeometry) {
        switch geometry.type {
        case .point:
            if let coords = geometry.pointCoordinates {
                extend(lat: coords[1], lon: coords[0])
            }
        case .lineString:
            if let coords = geometry.lineStringCoordinates {
                for coord in coords {
                    extend(lat: coord[1], lon: coord[0])
                }
            }
        case .polygon:
            if let coords = geometry.polygonCoordinates {
                for ring in coords {
                    for coord in ring {
                        extend(lat: coord[1], lon: coord[0])
                    }
                }
            }
        case .multiPoint:
            if let coords = geometry.multiPointCoordinates {
                for coord in coords {
                    extend(lat: coord[1], lon: coord[0])
                }
            }
        case .multiLineString:
            if let coords = geometry.multiLineStringCoordinates {
                for line in coords {
                    for coord in line {
                        extend(lat: coord[1], lon: coord[0])
                    }
                }
            }
        case .multiPolygon:
            if let coords = geometry.multiPolygonCoordinates {
                for poly in coords {
                    for ring in poly {
                        for coord in ring {
                            extend(lat: coord[1], lon: coord[0])
                        }
                    }
                }
            }
        }
    }
}
