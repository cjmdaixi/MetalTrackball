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
                          device float3 *computeOut [[buffer(1)]],
                          constant Uniforms & uniforms [[buffer(2)]],
                          uint vid [[thread_position_in_grid]],
                          uint pid [[thread_position_in_threadgroup]])
{
    float4 position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(positionsIn[vid], 1.0);;
    
    threadgroup float2 p[3];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    p[pid] = uniforms.viewportMatrix * position;
    threadgroup_barrier(mem_flags::mem_threadgroup);
        
    float a = length(p[1] - p[2]);
    float b = length(p[2] - p[0]);
    float c = length(p[1] - p[0]);
    
    float alpha = acos((b * b + c * c - a * a) / (2.0 * b * c));
    float beta = acos((a * a + c * c - b * b) / (2.0 * a * c));
    
    float ha = abs(c * sin(beta));
    float hb = abs(c * sin(alpha));
    float hc = abs(b * sin(alpha));
    
    float3 edge = float3(pid == 0? ha: 0, pid == 1? hb: 0, pid == 2? hc: 0);
    
    computeOut[vid] = edge;
}

typedef struct
{
    float4 position [[position]];
    float3 normal;
    float3 edge[[center_no_perspective]];
} VertexOut;

vertex VertexOut vertexShader(const device float3 *positionsIn [[buffer(0)]],
                              const device float3 *normals [[buffer(1)]],
                              const device float3 *computeIn [[buffer(2)]],
                              constant Uniforms & uniforms [[ buffer(3) ]],
                              uint vid[[vertex_id]])
{
    VertexOut out;
    out.edge = computeIn[vid];
    
    float4 position = float4(positionsIn[vid], 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    //out.normal = normal;
    out.normal = normalize(uniforms.normalMatrix * normals[vid]);
    return out;
}

constant float lineWidth = 1.2;
constant float3 lineColor = (0, 0, 0);

float3 shadeLine(float3 color, float3 edge){
    float d = min(edge.x, edge.y);
    d = min(d, edge.z);
    
    float mixVal;
    if(d < lineWidth - 1.0){
        mixVal = 1.0;
    }
    else if(d > lineWidth + 1.0){
        mixVal = 0.0;
    }
    else{
        float x = d - (lineWidth - 1.0);
        mixVal = exp2(-2.0 * (x * x));
    }
    return mix(color, lineColor, mixVal);
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               bool is_front_face [[ front_facing ]],
                               constant Uniforms & uniforms [[ buffer(0) ]])
{
    float3 light_dir (0, 0, -1);
    float direction = dot(light_dir, in.normal);
    float3 color;
    
    if(is_front_face){
        color = float3(1.0, 0, 0);
    }else{
        color = float3(0, 1.0, 0);
    }
    
    color = shadeLine(color, in.edge);
    
    float4 outputColor;
    if(is_front_face){
        outputColor = float4(color * abs(direction), 1.0);
    }else{
        outputColor = float4(color * abs(direction), 1.0);
    }
    return outputColor;
}
