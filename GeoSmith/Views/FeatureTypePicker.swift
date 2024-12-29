//
//  FeatureTypePicker.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import SwiftUI

// MARK: - Feature Type Picker
struct FeatureTypePicker: View {
    @Binding var selectedFeatureType: TrackFeatureType

    var body: some View {
        Text("TEST")
//        Picker("Feature Type", selection: $selectedFeatureType) {
//            Text("Circuit").tag(TrackFeatureType.circuit)
//            Text("Sector 1").tag(TrackFeatureType.sectorOne)
//            Text("Sector 2").tag(TrackFeatureType.sectorTwo)
//            Text("Sector 3").tag(TrackFeatureType.sectorThree)
//            Text("DRS Zone").tag(TrackFeatureType.drsZone)
//        }
//        .pickerStyle(.automatic)
    }
}
