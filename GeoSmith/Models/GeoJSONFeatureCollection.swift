//
//  GeoJSONFeatureCollection.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

enum GeoJSONFeatureCollectionType: String, Codable {
    case featureCollection = "FeatureCollection"
}

struct GeoJSONFeatureCollection: Codable {
    var type: GeoJSONFeatureCollectionType
    var features: [GeoJSONFeature]

    private var additionalProperties: [String: PropertyValue]?

    enum CodingKeys: String, CodingKey {
        case type, features
    }

    init(features: [GeoJSONFeature] = [], additionalProperties: [String: PropertyValue]? = nil) {
        self.type = .featureCollection
        self.features = features
        self.additionalProperties = additionalProperties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(GeoJSONFeatureCollectionType.self, forKey: .type)
        features = try container.decode([GeoJSONFeature].self, forKey: .features)

        let additionalKeys = Set(container.allKeys).subtracting([CodingKeys.type, CodingKeys.features])
        if !additionalKeys.isEmpty {
            var properties = [String: PropertyValue]()
            for key in additionalKeys {
                if let value = try? container.decode(PropertyValue.self, forKey: key) {
                    properties[key.stringValue] = value
                }
            }
            additionalProperties = properties
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(features, forKey: .features)

        if let additionalProperties = additionalProperties {
            for (key, value) in additionalProperties {
                if let codingKey = CodingKeys(stringValue: key) {
                    try container.encode(value, forKey: codingKey)
                }
            }
        }
    }
}
