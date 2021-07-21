//
//  downsample.metal
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position;
    float2 coord;
};

struct VertexOut {
    float4 position [[position]];
    float2 coord;
};

vertex VertexOut vertexFunc(const uint vertexID  [[ vertex_id ]]
                            , const device VertexIn * vertexIns [[ buffer(0) ]]
                            , const device float2 &sizeScale [[ buffer(1) ]]
                            ) {
        
    VertexOut out;
    
    VertexIn input = vertexIns[vertexID];
    out.position = float4(input.position, 0, 1);
    out.coord = input.coord;
    
    float2 pos = input.position.xy * sizeScale;
    out.position = float4(pos, 0, 1);
    
    return out;
}

fragment half4 fragmentFunc(VertexOut out [[ stage_in ]],
                             texture2d<half>  texture    [[ texture(0) ]],
                             constant float & mipmapBias [[ buffer(0) ]]) {
    
    constexpr sampler sampler(min_filter::nearest,
                       mag_filter::nearest,
                       mip_filter::nearest);
    
    half4 color = texture.sample(sampler, out.coord);
    return color;
}

