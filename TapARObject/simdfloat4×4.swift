//
//  simdfloat4×4.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/12.
//

import Foundation
import simd

extension float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3.x = translation.x
        columns.3.y = translation.y
        columns.3.z = translation.z
    }

    init(rotationX angle: Float) {
        self = matrix_identity_float4x4
        columns.1.y = cos(angle)
        columns.1.z = sin(angle)
        columns.2.y = -sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationY angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.z = -sin(angle)
        columns.2.x = sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationZ angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.y = sin(angle)
        columns.1.x = -sin(angle)
        columns.1.y = cos(angle)
    }

    init(rotation angle: SIMD3<Float>) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationX * rotationY * rotationZ
    }

    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let yValue = 1 / tan(fov * 0.5)
        let xValue = yValue / aspect
        let zValue = lhs ? far / (far - near) : far / (near - far)
        let x2Value = SIMD4<Float>(xValue, 0, 0, 0)
        let y2Value = SIMD4<Float>(0, yValue, 0, 0)
        let z2Value = lhs ? SIMD4<Float>(0, 0, zValue, 1) : SIMD4<Float>(0, 0, zValue, -1)
        let wValue = lhs ? SIMD4<Float>(0, 0, zValue * -near, 0) : SIMD4<Float>(0, 0, zValue * near, 0)
        self.init()
        columns = (x2Value, y2Value, z2Value, wValue)
    }

    var upVector: SIMD3<Float> {
        return SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)
    }

    var rightVector: SIMD3<Float> {
        return SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)
    }

    var forwardVector: SIMD3<Float> {
        return SIMD3<Float>(-columns.2.x, -columns.2.y, -columns.2.z)
    }

    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
