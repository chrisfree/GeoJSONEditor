//
//  InspectorView.swift
//  geoJSONEditor
//
//  Created by Christopher James Free on 12/15/24.
//

import SwiftUI

struct PropertyPair: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

struct InspectorView: View {
    @Binding var selectedFeatures: Set<UUID>
    @Binding var layers: [LayerState]
    
    // State for expanded fields and new property
    @State private var expandedFields: Set<String> = []
    @State private var newPropertyKey: String = ""
    @State private var newPropertyValue: String = ""
    @State private var orderedPropertyKeys: [String] = []
    @State private var scrollToTop = false
    
    // Your selectedFeature computed property remains the same
    private var selectedFeature: GeoJSONFeature? {
        guard let firstSelected = selectedFeatures.first,
              let layer = layers.first(where: { $0.feature.id == firstSelected }) else {
            return nil
        }
        return layer.feature
    }
    
    // Update function remains the same
    private func updateProperty(oldKey: String, newKey: String, value: String) {
        guard let selectedId = selectedFeatures.first,
              let layerIndex = layers.firstIndex(where: { $0.feature.id == selectedId }) else {
            return
        }
        
        // Create new properties dictionary if none exists
        var newProperties = layers[layerIndex].feature.properties ?? [:]
        if oldKey != newKey {
            newProperties.removeValue(forKey: oldKey)
        }
        newProperties[newKey] = PropertyValue.string(value)
        
        var updatedFeature = layers[layerIndex].feature
        updatedFeature.properties = newProperties
        layers[layerIndex].feature = updatedFeature
        
        // Update ordered keys
        if oldKey != newKey {
            if let index = orderedPropertyKeys.firstIndex(of: oldKey) {
                orderedPropertyKeys.remove(at: index)
                orderedPropertyKeys.insert(newKey, at: index)
            }
        }
    }
    
    // Delete function
    private func deleteProperty(key: String) {
        guard let selectedId = selectedFeatures.first,
              let layerIndex = layers.firstIndex(where: { $0.feature.id == selectedId }) else {
            return
        }
        
        // Create new properties dictionary if none exists
        var newProperties = layers[layerIndex].feature.properties ?? [:]
        newProperties.removeValue(forKey: key)
        
        var updatedFeature = layers[layerIndex].feature
        updatedFeature.properties = newProperties
        layers[layerIndex].feature = updatedFeature
        
        // Update ordered keys
        orderedPropertyKeys.removeAll { $0 == key }
    }
    
    // Add function
    private func addNewProperty() {
        guard !newPropertyKey.isEmpty,
              let selectedId = selectedFeatures.first,
              let layerIndex = layers.firstIndex(where: { $0.feature.id == selectedId }) else {
            return
        }
        
        // Create new properties dictionary if none exists
        var newProperties = layers[layerIndex].feature.properties ?? [:]
        newProperties[newPropertyKey] = PropertyValue.string(newPropertyValue)
        
        var updatedFeature = layers[layerIndex].feature
        updatedFeature.properties = newProperties
        layers[layerIndex].feature = updatedFeature
        
        // Update ordered keys
        orderedPropertyKeys.append(newPropertyKey)
        
        // Reset fields
        newPropertyKey = ""
        newPropertyValue = ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let feature = selectedFeature {
                Form {
                    VStack(alignment: .leading, spacing: 12) {
                        // Feature ID section
                        HStack {
                            Text("Feature ID")
                                .frame(width: 100, alignment: .trailing)
                            Text(feature.id.uuidString)
                                .textSelection(.enabled)
                        }
                        
                        Divider()
                        
                        // Feature Type sections
                        HStack {
                            Text("Type")
                                .frame(width: 100, alignment: .trailing)
                            Text("Feature")
                        }
                        
                        // Geometry Type
                        if let geometry = feature.geometry {
                            HStack {
                                Text("Geometry")
                                    .frame(width: 100, alignment: .trailing)
                                Text(geometry.type.rawValue)
                            }
                        }
                        
                        Divider()
                        
                        // Properties section header
                        Text("Properties")
                            .font(.headline)
                            .padding(.top)
                        
                        // Properties list with reordering
                        List {
                            Section {
                                ForEach(orderedPropertyKeys, id: \.self) { key in
                                    if let properties = feature.properties,
                                       let value = properties[key]?.stringValue {
                                        HStack(spacing: 8) {
                                            TextField("Key", text: Binding(
                                                get: { key },
                                                set: { updateProperty(oldKey: key, newKey: $0, value: value) }
                                            ))
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 100)
                                            
                                            if expandedFields.contains(key) {
                                                TextEditor(text: Binding(
                                                    get: { value },
                                                    set: { updateProperty(oldKey: key, newKey: key, value: $0) }
                                                ))
                                                .frame(height: 100)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                            } else {
                                                TextField("Value", text: Binding(
                                                    get: { value },
                                                    set: { updateProperty(oldKey: key, newKey: key, value: $0) }
                                                ))
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Button(action: {
                                                    if expandedFields.contains(key) {
                                                        expandedFields.remove(key)
                                                    } else {
                                                        expandedFields.insert(key)
                                                    }
                                                }) {
                                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                }
                                                
                                                Button(action: { deleteProperty(key: key) }) {
                                                    Image(systemName: "trash.circle")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                                .onMove(perform: { source, destination in
                                    orderedPropertyKeys.move(fromOffsets: source, toOffset: destination)
                                })
                            }
                            
                            // Add new property row at the end
                            HStack(spacing: 8) {
                                TextField("Key", text: $newPropertyKey, prompt: Text("Key").foregroundColor(.gray))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 100)
                                
                                TextField("Value", text: $newPropertyValue, prompt: Text("Value").foregroundColor(.gray))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: addNewProperty) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.borderless)
                                .disabled(newPropertyKey.isEmpty)
                            }
                            .padding(.top, 4)
                        }
                        .listStyle(.bordered(alternatesRowBackgrounds: true))
                        
                        Divider()
                        
                        Text("Statistics")
                            .font(.headline)
                            .padding(.top)
                        
                        // Update points count to use proper geometry coordinate access
                        if let geometry = feature.geometry,
                           let coords = geometry.lineStringCoordinates {
                            HStack {
                                Text("Points")
                                    .frame(width: 100, alignment: .trailing)
                                Text("\(coords.count)")
                            }
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .task(id: feature.id) {
                    // Reset and update ordered keys
                    expandedFields.removeAll()
                    if let properties = feature.properties {
                        orderedPropertyKeys = Array(properties.keys).sorted()
                    } else {
                        orderedPropertyKeys = []
                    }
                }
            } else {
                Text("No feature selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 300)
        .padding(.vertical)
    }
}
