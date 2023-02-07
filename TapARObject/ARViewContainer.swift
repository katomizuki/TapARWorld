//
//  ARViewContainer.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/07.
//

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    typealias UIViewType = CustomARView
    
    func makeUIView(context: Context) -> CustomARView {
        let arView = CustomARView(frame: .zero)
        return arView
    }
    
    func updateUIView(_ uiView: CustomARView, context: Context) {
    }
}
