//
//  GeoJSONFeatureCollection.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

struct GeoJSONFeatureCollection: Codable {
    var type: String
    var features: [GeoJSONFeature]

    enum CodingKeys: String, CodingKey {
        case type, features
    }

    init(features: [GeoJSONFeature]) {
        self.type = "FeatureCollection"
        self.features = features
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        features = try container.decode([GeoJSONFeature].self, forKey: .features)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(features, forKey: .features)
    }
}
