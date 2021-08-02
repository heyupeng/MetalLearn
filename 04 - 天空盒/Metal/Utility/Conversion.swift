//
//  Conversion.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/21.
//

import UIKit
import MetalKit
import GLKit

// MARK: GLKit
func GLKMatrix4ToMatrix4x4(_ matrix: GLKMatrix4) -> matrix_float4x4 {
    return matrix_float4x4(
        SIMD4<Float>(matrix.m00, matrix.m01, matrix.m02, matrix.m03),
        SIMD4<Float>(matrix.m10, matrix.m11, matrix.m12, matrix.m13),
        SIMD4<Float>(matrix.m20, matrix.m21, matrix.m22, matrix.m23),
        SIMD4<Float>(matrix.m30, matrix.m31, matrix.m32, matrix.m33))
}


extension GLKMatrix4 {
    func matrix4x4() -> matrix_float4x4 {
        return GLKMatrix4ToMatrix4x4(self)
    }
}

// MARK: UIKit
func CATransform3DToMatrix4x4(_ t: CATransform3D) -> matrix_float4x4 {
    let c1 = simd_float4(Float(t.m11), Float(t.m12), Float(t.m13), Float(t.m14))
    let c2 = simd_float4(Float(t.m21), Float(t.m22), Float(t.m23), Float(t.m24))
    let c3 = simd_float4(Float(t.m31), Float(t.m32), Float(t.m33), Float(t.m34))
    let c4 = simd_float4(Float(t.m41), Float(t.m42), Float(t.m43), Float(t.m44))
    let matrix =  matrix_float4x4(columns: (c1, c2, c3, c4))
    return matrix
}

extension CATransform3D {
    func matrix4x4() -> matrix_float4x4 {
        return CATransform3DToMatrix4x4(self)
    }
}

func matrix4x4_to_matrix3x3(_ m: matrix_float4x4) -> matrix_float3x3 {
    let c0 = m.columns.0
    let c1 = m.columns.1
    let c2 = m.columns.2
    return matrix_float3x3(simd_float3(c0.x, c0.y, c0.z),
                           simd_float3(c1.x, c1.y, c1.z),
                           simd_float3(c2.x, c2.y, c2.z))
}

extension matrix_float4x4 {
    func matrix3x3() ->matrix_float3x3 {
        return matrix4x4_to_matrix3x3(self)
    }
}
