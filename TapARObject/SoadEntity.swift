//
//  SoadEntity.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/08.
//

import ARKit
import RealityKit
import RealityGeometries


final class SoadGeometry: Entity, HasPhysicsBody {
    private let cylinder: ModelEntity = {
            let meshResource: MeshResource = try! MeshResource.generateCylinder(radius: 0.02,
                                                                           height: 1)
            let material: SimpleMaterial = SimpleMaterial(color: .red,isMetallic: false)
            let modelEntity: ModelEntity = ModelEntity(mesh: meshResource, materials: [material])
            return modelEntity
    }()
    
    required init() {
        super.init()
        addChild(cylinder)
    }
    
    func update(worldTransform:  simd_float4x4?) {
        let rotationMatrix = simd_float4x4(SCNMatrix4Mult(
                                            SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0),
                                            SCNMatrix4MakeTranslation(0, 0, 0.1 / 2)))
        if let worldTransform = worldTransform {
            cylinder.transform = Transform(matrix: worldTransform * rotationMatrix)
        }
    }
    
}
