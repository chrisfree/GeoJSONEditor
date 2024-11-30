//
//  SelectionState.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/30/24.
//

import Foundation

@MainActor
class SelectionState: ObservableObject {
    @Published var selectedPoints: [Int] = []
    @Published var lastSelectedPoint: Int? = nil

    func clearPointSelection() {
        selectedPoints = []
        lastSelectedPoint = nil
    }

    func selectPoint(_ index: Int, mode: SelectionMode = .single) {
        switch mode {
            case .single:
                selectedPoints = [index]
                lastSelectedPoint = index
            case .additive:
                if let existingIndex = selectedPoints.firstIndex(of: index) {
                    selectedPoints.remove(at: existingIndex)
                } else {
                    selectedPoints.append(index)
                }
                lastSelectedPoint = index
            case .range:
                if let last = lastSelectedPoint {
                    let range = min(last, index)...max(last, index)
                    let newIndices = Array(range)
                    selectedPoints.removeAll { newIndices.contains($0) }
                    selectedPoints.append(contentsOf: newIndices)
                } else {
                    selectedPoints = [index]
                }
                lastSelectedPoint = index
        }
    }
}

enum SelectionMode {
    case single
    case additive
    case range
}
