//
//  GeoJSONGeometry.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

enum GeometryType: String, Codable {
    case point = "Point"
    case lineString = "LineString"
    case polygon = "Polygon"
    case multiPoint = "MultiPoint"
    case multiLineString = "MultiLineString"
    case multiPolygon = "MultiPolygon"
}

struct GeoJSONGeometry: Codable {
    var type: GeometryType
    var coordinates: Any
    
    enum CodingKeys: String, CodingKey {
        case coordinates, type
    }
    
    init(type: GeometryType, coordinates: Any) {
        self.type = type
        self.coordinates = coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(GeometryType.self, forKey: .type)
        
        switch type {
        case .point:
            coordinates = try container.decode([Double].self, forKey: .coordinates)
        case .lineString:
            coordinates = try container.decode([[Double]].self, forKey: .coordinates)
        case .polygon:
            coordinates = try container.decode([[[Double]]].self, forKey: .coordinates)
        case .multiPoint:
            coordinates = try container.decode([[Double]].self, forKey: .coordinates)
        case .multiLineString:
            coordinates = try container.decode([[[Double]]].self, forKey: .coordinates)
        case .multiPolygon:
            coordinates = try container.decode([[[[Double]]]].self, forKey: .coordinates)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch type {
        case .point:
            try container.encode(coordinates as! [Double], forKey: .coordinates)
        case .lineString:
            try container.encode(coordinates as! [[Double]], forKey: .coordinates)
        case .polygon:
            try container.encode(coordinates as! [[[Double]]], forKey: .coordinates)
        case .multiPoint:
            try container.encode(coordinates as! [[Double]], forKey: .coordinates)
        case .multiLineString:
            try container.encode(coordinates as! [[[Double]]], forKey: .coordinates)
        case .multiPolygon:
            try container.encode(coordinates as! [[[[Double]]]], forKey: .coordinates)
        }
    }
    
    var pointCoordinates: [Double]? {
        guard type == .point else { return nil }
        return coordinates as? [Double]
    }
    
    var lineStringCoordinates: [[Double]]? {
        guard type == .lineString else { return nil }
        return coordinates as? [[Double]]
    }
    
    var polygonCoordinates: [[[Double]]]? {
        guard type == .polygon else { return nil }
        return coordinates as? [[[Double]]]
    }
    
    var multiPointCoordinates: [[Double]]? {
        guard type == .multiPoint else { return nil }
        return coordinates as? [[Double]]
    }
    
    var multiLineStringCoordinates: [[[Double]]]? {
        guard type == .multiLineString else { return nil }
        return coordinates as? [[[Double]]]
    }
    
    var multiPolygonCoordinates: [[[[Double]]]]? {
        guard type == .multiPolygon else { return nil }
        return coordinates as? [[[[Double]]]]
    }
}
