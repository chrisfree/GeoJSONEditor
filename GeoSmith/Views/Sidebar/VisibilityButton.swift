//
//  VisibilityButton.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct VisibilityButton: View {
    let layer: LayerState
    @Binding var layers: [LayerState]
    @State private var isHovering = false

    private var isVisible: Binding<Bool> {
        Binding(
            get: { layer.isVisible },
            set: { newValue in
                if let index = layers.firstIndex(where: { $0.id == layer.id }) {
                    layers[index].isVisible = newValue
                }
            }
        )
    }

    var body: some View {
        Button(action: {
            isVisible.wrappedValue.toggle()
        }) {
            Image(systemName: isVisible.wrappedValue ? "eye" : "eye.slash")
                .imageScale(.small)
                .foregroundColor(
                    isVisible.wrappedValue ?
                        NSColor.labelColor.asColor :
                        isHovering ?
                            NSColor.labelColor.asColor :
                            NSColor.secondaryLabelColor.asColor
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .help(isVisible.wrappedValue ? "Hide" : "Show")
    }
}
