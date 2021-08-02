//
//  ShaderTypes.h
//  MetalDemo
//
//  Created by Peng on 2021/7/20.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#import <simd/simd.h>

#ifdef __cplusplus

namespace AAPL
{
    typedef struct
    {
        simd::float4x4 modelview_projection_matrix;
        simd::float4x4 normal_matrix;
        simd::float4   ambient_color;
        simd::float4   diffuse_color;
        int            multiplier;
    } constants_t;
}

#endif

#endif /* ShaderTypes_h */
