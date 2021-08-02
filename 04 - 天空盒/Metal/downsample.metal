//
//  downsample.metal
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

struct MatrixContants {
    float4x4 modelViewProjetionMatrix;
    
    float4x4 projectionMatrix;
    
    float4x4 viewMatrix;
    
    float4x4 modelMatrix;
    float4x4 modelInvMatrix;
    
    /// viewMatrix 逆矩阵
    float4x4 viewInvMatrix;
    
    float4x4 projectionInvMatrix;    
    float3 projector;
    
    float3x3 normalMatrix;

};

struct PackedVertex3D {
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
    
    float3 pos;
};

// MARK: --

// 默认采样器。方便使用
constexpr sampler kDefaultSampler(min_filter::linear,
                                  mag_filter::linear
                                  );

constant half3 kRec709Luma(.2126f,.7152f,.0722f);

// Maximum value for HDR samples (prevent Inf samples from source HDR textures)
constant float kHDRMaxValue = 500.f;

constant float3 lightPostion(5, 5, 5);

// MARK: --

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
                                 , constant PackedVertex3D * vertexIns [[ buffer(0) ]]
                                 , constant MatrixContants & contants [[ buffer(1) ]]
                                 ) {
    VertexOut out;

    PackedVertex3D input = vertexIns[vertexID];
    
    float4 pos = contants.modelViewProjetionMatrix * float4(input.position, 1);
    out.position = pos;
    out.coord = input.coord;
    
    return out;
}

// MARK: --
// Helper for equirectangular textures
half4 EquirectangularSample(float3 direction, sampler s, texture2d<half> image)
{
    float3 d = normalize(direction);

    float2 t = float2((atan2(d.z, d.x) + M_PI_F) / (2.f * M_PI_F), acos(d.y) / M_PI_F);

    return image.sample(s, t);
}

// 修改Z轴方向。
half4 EquirectangularSample1(float3 direction, sampler s, texture2d<half> texture)
{
    float3 n = normalize(direction);
    n.z *= -1;
    
    float2 t = float2(0, 0);
    t.x = (atan2(n.z, n.x) + M_PI_F) / (2.f * M_PI_F);
    t.y = acos(n.y) / M_PI_F;
    
    half4 c = half4(texture.sample(s, t));
    return c;
}



// MARK: 天空盒
//constant float2 kSkyDomeDirections[] = { float2(-1.f, 1.f), float2(1.f, 1.f), float2(-1.f, -1.f), float2(1.f, 1.f), float2(1.f, -1.f), float2(-1.f, -1.f)};

vertex VertexOut skyDome_vertex(const uint vertexID  [[ vertex_id ]]
                               , constant Vertex2D * vertexIns [[ buffer(0) ]]
                               , constant MatrixContants & contants [[ buffer(1) ]]
                               )
{
    VertexOut out;
        
    Vertex2D in = vertexIns[vertexID];
    
    float4 position = float4(in.position, 0.99, 1);
    out.position = position;
        
    float3 pos = float3(out.position.xy, 1);
    pos *= contants.projector.xyz;
    pos = (contants.viewInvMatrix * float4(pos, 1)).xyz;
    
//    float3 eye = (contants.viewInvMatrix).columns[3].xyz;
//    pos = out.position.xyz - eye;
//    pos = normalize(pos);
//    pos *= float3(contants.projector.z,contants.projector.z,contants.projector.z);
//    pos = (contants.projectionMatrix * contants.viewMatrix * float4(pos, 1)).xyz;
//    pos = reflect(pos, normalize(out.position.xyz));
//    pos.y *= -1;
    
    pos = normalize(pos);
    out.pos = pos;
    
    return out;
}

fragment half4 skyDome_fragment(VertexOut inout [[ stage_in ]],
                               texture2d<float, access::sample> texture [[ texture(0) ]]
                            )
{
    
    constexpr sampler sampler(min_filter::linear,
                              mag_filter::linear
                              );
    
    float3 pos = inout.pos;
    pos = normalize(pos);
    pos.z *= -1;
    
    float2 t = float2(0, 0);
    t.x = (atan2(pos.z, pos.x) + M_PI_F) / (2.f * M_PI_F);
    t.y = acos(pos.y) / M_PI_F;
    
    half4 color = half4(texture.sample(sampler, t));
    return color;
}

// MARK: 天体
struct SphereVertexInput {
    float3 position;
    float3 normal;
};

struct SphereVertexOut {
    float4 position [[position]];
    float3 normal;
    float3 coord;
    
    float3 viewNormal;
    float3 reflect;
};

vertex SphereVertexOut sphere_vertex(const uint vertexID  [[ vertex_id ]]
                               , constant SphereVertexInput * vertexIns [[ buffer(0) ]]
                               , constant MatrixContants & contants [[ buffer(1) ]]
                               )
{
    SphereVertexOut out;
    
    SphereVertexInput input = vertexIns[vertexID];
    out.position = contants.projectionMatrix * contants.viewMatrix * contants.modelMatrix * float4(input.position, 1.0);
    
    out.normal = input.normal;
    out.coord = input.normal;
    
    out.normal = (contants.modelMatrix * float4(input.normal, 1)).xyz;
    
    // 反射
    float3 eyePos = (contants.viewInvMatrix.columns[3]).xyz;
    // 增加世界坐标矩阵
    eyePos = ((contants.modelInvMatrix * contants.viewInvMatrix).columns[3]).xyz;
    float3 eyeNor = normalize(input.position - eyePos);
    float3 ref = reflect(eyeNor, input.normal);
    
    out.reflect = ref;
    
    // 视觉空间下的法向量 (PostProcessingPipeline示例，不需要使用逆转置。)
//    out.viewNormal = contants.normalMatrix * input.normal;
    out.viewNormal = normalize(contants.viewMatrix * contants.modelMatrix * float4(input.normal, 0)).xyz;
    
    return out;
}


fragment half4 sphere_fragment(SphereVertexOut inout [[ stage_in ]],
                               texture2d<half, access::sample> texture [[ texture(0) ]]
                            )
{
    float3 nor = inout.reflect;
    
    half4 color = ::EquirectangularSample1(nor, kDefaultSampler, texture);
    
    /// 增加探照灯效果，计算色彩比
    float cosA = dot(inout.viewNormal, normalize(lightPostion));
    float factor = 1 - saturate(cosA) * 0.75;
    color = half(factor) * color + (1 - factor) * half4(0.1,0.5,0.3, 0.5);
    
    color = half4(clamp(color.rgb, 0.f, kHDRMaxValue), 1.f);
    return color;
}
