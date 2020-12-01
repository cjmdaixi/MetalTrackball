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

typedef struct
{
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float size[[point_size]];
    float3 normal;
} ColorInOut;

kernel void computeNormal(const device float3 *in_positions [[ buffer(0) ]],
                          device float3  *out_normals [[ buffer(1) ]],
                          uint id [[ thread_position_in_grid ]])
{
    float3 p0 = in_positions[id * 3];
    float3 p1 = in_positions[id * 3 + 1];
    float3 p2 = in_positions[id * 3 + 2];
    float3 v0 = p1 - p0;
    float3 v1 = p2 - p0;
    float3 n = v0 * v1;
    //auto n = float3(0.5, 0.5, 0);
    out_normals[id * 3] = n;
    out_normals[id * 3 + 1] = n;
    out_normals[id * 3 + 2] = n;
//    out_normals[p0_idx] = p0;
//    out_normals[p1_idx] = p1;
//    out_normals[p2_idx] = p2;
}

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    //out.normal = normal;
    out.normal = normalize(uniforms.normalMatrix * in.normal);
    out.size = 200 * (1 / out.position.z);
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               bool is_front_face [[ front_facing ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
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
