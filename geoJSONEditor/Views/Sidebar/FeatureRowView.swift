//
//  FeatureRowView.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct FeatureRowView: View {
    let layer: LayerState
    @Binding var layers: [LayerState]
    @Binding var editingState: EditingState
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showingDeleteAlert: Bool = false
    @State private var isShowingPoints: Bool = false  // New state for points visibility

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Main row with feature name and controls
            HStack {
                // Disclosure triangle for points
                Button(action: {
                    isShowingPoints.toggle()
                }) {
                    Image(systemName: isShowingPoints ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(isShowingPoints ? "Hide Points" : "Show Points")

                VisibilityButton(layer: layer, layers: $layers)

                if isEditingName {
                    TextField("Feature Name",
                              text: $editedName,
                              onCommit: {
                        updateFeatureName(editedName)
                        isEditingName = false
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(layer.feature.properties["name"]?.stringValue ??
                         layer.feature.properties["Name"]?.stringValue ??
                         "Unnamed Feature")
                }

                Spacer()

                if editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id {
                    Text("Editing")
                        .foregroundColor(.primary)
                }

                Group {
                    // Edit Button
                    Button(action: {
                        toggleEditMode()
                    }) {
                        Image(systemName: "pencil")
                            .imageScale(.small)
                    }
                    .buttonStyle(HoverButtonStyle(isEditing: editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id))
                    .help(editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id
                          ? "Exit Edit Mode"
                          : "Edit Feature")

                    // Duplicate Button
                    Button(action: {
                        duplicateFeature()
                    }) {
                        Image(systemName: "plus.square.on.square")
                            .imageScale(.small)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Duplicate Feature")

                    // Delete Button
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .imageScale(.small)
                    }
                    .buttonStyle(HoverDeleteButtonStyle())
                    .help("Delete Feature")
                }
            }
            .padding(.vertical, 2)

            // Points list (shown when expanded)
            if isShowingPoints {
                FeaturePointsView(
                    coordinates: layer.feature.geometry.coordinates,
                    layerId: layer.id,
                    editingState: $editingState,
                    layers: $layers
                )
                .padding(.leading, 28)
            }
        }
        .listRowBackground(Color(NSColor.alternatingContentBackgroundColors[1])) 
        .listRowSeparator(.hidden)
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Feature"),
                message: Text("Are you sure you want to delete this feature? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteFeature()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func deleteFeature() {
        // If we're deleting the feature being edited, exit edit mode
        if editingState.isEnabled && editingState.selectedFeatureId == layer.id {
            editingState.isEnabled = false
            editingState.selectedFeatureId = nil
            editingState.modifiedCoordinates = nil
        }

        // Remove the layer
        layers.removeAll { $0.id == layer.id }

        // After deletion, make all remaining layers visible
        for i in 0..<layers.count {
            layers[i].isVisible = true
        }
    }

    private func duplicateFeature() {
        // Get the current name of the feature
        let currentName = layer.feature.properties["name"]?.stringValue ??
        layer.feature.properties["Name"]?.stringValue ??
        "Unnamed Feature"

        // Create a copy of the feature
        var duplicatedFeature = layer.feature

        // Generate a new UUID
        duplicatedFeature.id = UUID()

        // Update properties with new name
        var newProperties = duplicatedFeature.properties
        newProperties["name"] = .string("\(currentName) copy")
        duplicatedFeature.properties = newProperties

        // Create a new LayerState with the duplicated feature
        var newLayer = LayerState(feature: duplicatedFeature)

        // Add the new layer to the layers array
        layers.append(newLayer)

        // Set up name editing for the new feature
        editedName = "\(currentName) copy"
        isEditingName = true

        // Select and enter edit mode for the new feature
        editingState.isEnabled = true
        editingState.selectedFeatureId = duplicatedFeature.id

        // Update visibility
        for i in 0..<layers.count {
            layers[i].isVisible = (layers[i].feature.id == duplicatedFeature.id)
        }
    }

    private func updateFeatureName(_ newName: String) {
        if let index = layers.firstIndex(where: { $0.id == layer.id }) {
            var updatedFeature = layers[index].feature
            var properties = updatedFeature.properties
            properties["name"] = .string(newName)
            updatedFeature.properties = properties
            layers[index].feature = updatedFeature
        }
    }

    private func toggleEditMode() {
        if editingState.isEnabled && editingState.selectedFeatureId == layer.feature.id {
            // Exiting edit mode
            editingState.isEnabled = false
            editingState.selectedFeatureId = nil
            editingState.modifiedCoordinates = nil

            // Restore all layers visibility
            for i in 0..<layers.count {
                layers[i].isVisible = true
            }
        } else {
            // Entering edit mode
            editingState.isEnabled = true
            editingState.selectedFeatureId = layer.feature.id

            // Hide all layers except the selected one
            for i in 0..<layers.count {
                layers[i].isVisible = (layers[i].feature.id == layer.feature.id)
            }
        }
    }
}
