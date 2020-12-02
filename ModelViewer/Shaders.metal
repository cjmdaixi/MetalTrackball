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
} VertexIn;

typedef struct
{
    float3 position;
    float3 normal;
} ComputeVertexOut;

typedef struct
{
    float4 position [[position]];
    float3 original_position;
    float size[[point_size]];
    float3 normal;
    float3 center[[flat]];
    float radius [[flat]];
} ColorInOut;

vertex ColorInOut vertexShader(VertexIn in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    //out.normal = normal;
    out.normal = normalize(uniforms.normalMatrix * in.normal);
    out.size = 25;//00 * (1 / out.position.z);
    out.radius = out.size * out.size;
    out.center = float3(out.position);
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
