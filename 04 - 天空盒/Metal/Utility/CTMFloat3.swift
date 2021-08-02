//
//  CTMFloat3.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/30.
//

import Foundation
import Metal

/// 对应 packed_float3。packed_float3 内存大小为 4 * 3 = 12 byte ，swift 中 vector_float3 的内存大小为 4 * 4 = 16 byte。可使用 `MTLPackedFloat3`。

#if true

public typealias CTMFloat3 = MTLPackedFloat3

#else

extension MTLPackedFloat3: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(x), \(y), \(z))"
    }
}

public struct CTMFloat3 {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    
    public init() {
        
    }
    
    init(_ x: Float, _ y: Float = 0, _ z: Float = 0) {
        self.init()
        self.x = x
        self.y = y
        self.z = z
    }
}

extension CTMFloat3 {
    public static func + (lhs: Self, rhs: Self) -> Self {
        return CTMFloat3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    public static func * (lhs: Self, rhs: Self) -> Self {
        return CTMFloat3(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }
    
    public static func * (lhs: Self, rhs: Float) -> Self {
        return CTMFloat3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}

#endif

extension CTMFloat3 {
    
    public static var zero: CTMFloat3 {
        return CTMFloat3()
    }
    
    var SIMD3:SIMD3<Float> {
        return Swift.SIMD3(x, y, z)
    }
    
    init(SIMDFloat3: SIMD3<Float>) {
        self.init()
        x = SIMDFloat3.x
        y = SIMDFloat3.y
        z = SIMDFloat3.z
    }
}

extension CTMFloat3: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(x), \(y), \(z))"
    }
}
