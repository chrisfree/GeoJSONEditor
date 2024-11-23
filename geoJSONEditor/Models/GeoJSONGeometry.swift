//
//  GeoJSONGeometry.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

struct GeoJSONGeometry: Codable {
    var type: String
    var coordinates: [[Double]]

    enum CodingKeys: String, CodingKey {
        case coordinates, type
    }

    init(type: String, coordinates: [[Double]]) {
        self.type = type
        self.coordinates = coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coordinates = try container.decode([[Double]].self, forKey: .coordinates)
        type = try container.decode(String.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinates, forKey: .coordinates)
        try container.encode(type, forKey: .type)
    }
}
