//
//  GeoJSONGeometry.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

// Define all possible geometry types
enum GeoJSONGeometryType: String, Codable {
    case point = "Point"
    case multiPoint = "MultiPoint"
    case lineString = "LineString"
    case multiLineString = "MultiLineString"
    case polygon = "Polygon"
    case multiPolygon = "MultiPolygon"
    case geometryCollection = "GeometryCollection"
}

// Type alias for clarity
typealias Position = [Double]  // [longitude, latitude]
typealias PositionArray = [Position]
typealias LineStringCoordinates = [Position]
typealias MultiLineStringCoordinates = [LineStringCoordinates]
typealias PolygonCoordinates = [LineStringCoordinates]  // First is exterior, rest are holes
typealias MultiPolygonCoordinates = [PolygonCoordinates]

struct GeoJSONGeometry: Codable {
    let type: GeoJSONGeometryType
    private let coordinates: Any?  // We'll use this to store the raw coordinates
    private let geometries: [GeoJSONGeometry]?  // For GeometryCollection
    
    // Public accessor for raw coordinates when working with LineStrings
    var lineStringCoordinates: [[Double]]? {
        guard type == .lineString else { return nil }
        return coordinates as? [[Double]]
    }
    
    // Computed properties to access coordinates in their proper form
    var pointCoordinates: Position? {
        guard type == .point else { return nil }
        return coordinates as? Position
    }
    
    var multiPointCoordinates: PositionArray? {
        guard type == .multiPoint else { return nil }
        return coordinates as? PositionArray
    }
    
    var multiLineStringCoordinates: MultiLineStringCoordinates? {
        guard type == .multiLineString else { return nil }
        return coordinates as? MultiLineStringCoordinates
    }
    
    var polygonCoordinates: PolygonCoordinates? {
        guard type == .polygon else { return nil }
        return coordinates as? PolygonCoordinates
    }
    
    var multiPolygonCoordinates: MultiPolygonCoordinates? {
        guard type == .multiPolygon else { return nil }
        return coordinates as? MultiPolygonCoordinates
    }
    
    var geometryCollectionGeometries: [GeoJSONGeometry]? {
        guard type == .geometryCollection else { return nil }
        return geometries
    }
    
    // Helper method to check if coordinates are empty
    func hasCoordinates() -> Bool {
        switch type {
        case .lineString:
            return lineStringCoordinates?.isEmpty == false
        case .point:
            return pointCoordinates != nil
        case .multiPoint:
            return multiPointCoordinates?.isEmpty == false
        case .multiLineString:
            return multiLineStringCoordinates?.isEmpty == false
        case .polygon:
            return polygonCoordinates?.isEmpty == false
        case .multiPolygon:
            return multiPolygonCoordinates?.isEmpty == false
        case .geometryCollection:
            return geometries?.isEmpty == false
        }
    }
    
    // Custom initializers for each type
    init(point: Position) {
        self.type = .point
        self.coordinates = point
        self.geometries = nil
    }
    
    init(multiPoint: PositionArray) {
        self.type = .multiPoint
        self.coordinates = multiPoint
        self.geometries = nil
    }
    
    init(lineString: LineStringCoordinates) {
        self.type = .lineString
        self.coordinates = lineString
        self.geometries = nil
    }
    
    init(multiLineString: MultiLineStringCoordinates) {
        self.type = .multiLineString
        self.coordinates = multiLineString
        self.geometries = nil
    }
    
    init(polygon: PolygonCoordinates) {
        self.type = .polygon
        self.coordinates = polygon
        self.geometries = nil
    }
    
    init(multiPolygon: MultiPolygonCoordinates) {
        self.type = .multiPolygon
        self.coordinates = multiPolygon
        self.geometries = nil
    }
    
    init(geometryCollection: [GeoJSONGeometry]) {
        self.type = .geometryCollection
        self.coordinates = nil
        self.geometries = geometryCollection
    }
    
    enum CodingKeys: String, CodingKey {
        case type, coordinates, geometries
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(GeoJSONGeometryType.self, forKey: .type)
        
        // Initialize coordinates and geometries based on type
        switch type {
        case .geometryCollection:
            self.coordinates = nil
            self.geometries = try container.decode([GeoJSONGeometry].self, forKey: .geometries)
            
        case .point:
            self.coordinates = try container.decode(Position.self, forKey: .coordinates)
            self.geometries = nil
            
        case .multiPoint:
            self.coordinates = try container.decode(PositionArray.self, forKey: .coordinates)
            self.geometries = nil
            
        case .lineString:
            self.coordinates = try container.decode(LineStringCoordinates.self, forKey: .coordinates)
            self.geometries = nil
            
        case .multiLineString:
            self.coordinates = try container.decode(MultiLineStringCoordinates.self, forKey: .coordinates)
            self.geometries = nil
            
        case .polygon:
            self.coordinates = try container.decode(PolygonCoordinates.self, forKey: .coordinates)
            self.geometries = nil
            
        case .multiPolygon:
            self.coordinates = try container.decode(MultiPolygonCoordinates.self, forKey: .coordinates)
            self.geometries = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch type {
        case .geometryCollection:
            try container.encode(geometries, forKey: .geometries)
        default:
            switch type {
            case .point:
                try container.encode(coordinates as! Position, forKey: .coordinates)
            case .multiPoint:
                try container.encode(coordinates as! PositionArray, forKey: .coordinates)
            case .lineString:
                try container.encode(coordinates as! LineStringCoordinates, forKey: .coordinates)
            case .multiLineString:
                try container.encode(coordinates as! MultiLineStringCoordinates, forKey: .coordinates)
            case .polygon:
                try container.encode(coordinates as! PolygonCoordinates, forKey: .coordinates)
            case .multiPolygon:
                try container.encode(coordinates as! MultiPolygonCoordinates, forKey: .coordinates)
            case .geometryCollection:
                break
            }
        }
    }
}
