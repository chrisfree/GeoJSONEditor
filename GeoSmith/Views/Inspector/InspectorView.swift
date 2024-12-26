//
//  InspectorView.swift
//  geoJSONEditor
//
//  Created by Christopher James Free on 12/15/24.
//


import SwiftUI

struct InspectorView: View {
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    
    private var selectedFeature: GeoJSONFeature? {
        guard let firstSelected = selectedFeatures.first,
              let layer = layers.first(where: { $0.feature.id == firstSelected }) else {
            return nil
        }
        return layer.feature
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let feature = selectedFeature {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Feature ID section remains the same
                        LabeledContent("Feature ID") {
                            Text(feature.id.uuidString)
                                .textSelection(.enabled)
                        }
                        
                        // Feature Type section remains the same
                        LabeledContent("Type") {
                            Text(feature.type)
                        }
                        
                        // Modified Properties section
                        Text("Properties")
                            .font(.headline)
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            let propertyPairs = feature.properties.map { (key: $0.key, value: $0.value.stringValue) }
                                .sorted { $0.key < $1.key }
                            
                            ForEach(propertyPairs, id: \.key) { pair in
                                LabeledContent(pair.key) {
                                    Text(pair.value)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        
                        // Points section remains the same
                        LabeledContent("Points") {
                            Text("\(feature.geometry.coordinates.count)")
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("No feature selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 250)
    }
}
