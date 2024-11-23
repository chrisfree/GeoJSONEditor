//
//  HoverButtonStyle.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

struct HoverButtonStyle: ButtonStyle {
    var isEditing: Bool = false

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isEditing ? NSColor.systemBlue.asColor :
                    isHovering ? NSColor.labelColor.asColor :
                    NSColor.secondaryLabelColor.asColor
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct HoverDeleteButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isHovering ? NSColor.systemRed.asColor :
                    NSColor.secondaryLabelColor.asColor
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
