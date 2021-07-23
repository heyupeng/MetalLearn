//
//  downsample.metal
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

#include <metal_stdlib>
using namespace metal;

struct MatrixContants {
    float4x4 modelViewProjetionMatrix;
};

struct MeshVertex3 {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 coord;
};

struct Vertex2D {
    float2 position;
    float2 coord;
};

struct VertexOut {
    float4 position [[position]];
    float2 coord;
};

vertex VertexOut vertexFunc(const uint vertexID  [[ vertex_id ]]
                            , constant Vertex2D * vertexIns [[ buffer(0) ]]
                            , const device float2 &sizeScale [[ buffer(1) ]]
                            ) {
    VertexOut out;
    
    Vertex2D input = vertexIns[vertexID];
    out.position = float4(input.position, 0, 1);
    out.coord = input.coord;
    
    if (sizeScale.x != 0 && sizeScale.y != 0) {
        float2 pos = input.position.xy * sizeScale;
        out.position = float4(pos, 0, 1);
    }
    
    return out;
}

// stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
fragment half4 fragmentFunc(VertexOut out [[ stage_in ]],
                            texture2d<float, access::sample> texture [[ texture(0) ]]
                            ) {
    
    constexpr sampler sampler(min_filter::linear,
                              mag_filter::linear
                              );
    
    half4 color = half4(texture.sample(sampler, abs(out.coord)));
    
    return color;
}

vertex VertexOut vertexFunc_mesh(const uint vertexID  [[ vertex_id ]]
                                 , constant MeshVertex3 * vertexIns [[ buffer(0) ]]
                                 , constant MatrixContants & contants [[ buffer(1) ]]
                                 ) {
    VertexOut out;

    MeshVertex3 input = vertexIns[vertexID];
    
    float4 pos = contants.modelViewProjetionMatrix * float4(input.position, 1);
    out.position = pos;
    out.coord = input.coord;
    
    return out;
}

