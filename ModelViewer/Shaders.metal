//
//  Shaders.metal
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/24.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"
using namespace metal;



kernel void computeShader(device float3 *positionsIn [[buffer(0)]],
                          device ComputeVertexOut *positionsOut [[buffer(1)]],
                          constant Uniforms & uniforms [[buffer(2)]],
                          uint vid [[thread_position_in_grid]],
                          uint l [[thread_position_in_threadgroup]])
{
    ComputeVertexOut out;
    out.position = positionsIn[vid];
    positionsOut[vid] = out;
}

typedef struct
{
    float4 position [[position]];
    float3 normal;
} VertexOut;

vertex VertexOut vertexShader(const device ComputeVertexOut *computeIn [[buffer(0)]],
                              const device float3 *normals [[buffer(1)]],
                              uint vid[[vertex_id]],
                              constant Uniforms & uniforms [[ buffer(2) ]])
{
    ComputeVertexOut in = computeIn[vid];
    VertexOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    //out.normal = normal;
    out.normal = normalize(uniforms.normalMatrix * normals[vid]);
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               bool is_front_face [[ front_facing ]],
                               constant Uniforms & uniforms [[ buffer(0) ]])
{
    float3 light_dir (0, 0, -1);
    float direction = dot(light_dir, in.normal);
    float4 color;
    
    if(is_front_face){
        color = float4(float3(1.0, 0, 0) * abs(direction), 1.0);
    }else{
        color = float4(float3(0, 1.0, 0) * abs(direction), 1.0);
    }
    //color = float4(1, 0, 0, 1);
    return color;
}
