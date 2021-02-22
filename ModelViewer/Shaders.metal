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

void DirectionalLight(constant LightSource &light, float3 normal, float3 eye, float shininess, thread float4 &ambient, thread float4 &diffuse, thread float4 &specular)
{
    float3 VP = normalize(light.position);
    float3 HV = normalize(VP + eye);
    
    float nDotVP = saturate(dot(normal, VP));
    float nDotHV = saturate(dot(normal, HV));
    float spec = pow(nDotHV, shininess) * (shininess + 2.0) / 8.0;
    
    if(isnan(spec)){
        spec = 0.0;
    }
    
    ambient += light.ambient;
    diffuse += light.diffuse * nDotVP;
    specular += light.specular * spec * nDotVP;
}

constant float3 eye = float3(0.0, 0.0, -1.0);

float4 Lighting(constant LightSource &light, constant Material &material, float3 normal)
{
    float4 ambient = float4(0.0);
    float4 diffuse = float4(0.0);
    float4 specular = float4(0.0);
    
    DirectionalLight(light, normal, eye, material.shininess, ambient, diffuse, specular);
    
    float4 color = float4(0.0);
    color += (ambient * material.ambient);
    color += (diffuse * material.diffuse);
    color += (specular * material.specular);
    color.a = material.ambient.a;
    
    return color;
}

typedef struct
{
    float4 position [[position]];
    float4 frontColor [[flat]];
    float4 backColor[[flat]];
} VertexOut;

constant float3 light_vert = float3(0.5, 0.5, 1.0);

vertex VertexOut vertexShader(const device float3 *positionsIn [[buffer(0)]],
                              const device float3 *normals [[buffer(1)]],
                              constant Uniforms & uniforms [[ buffer(2) ]],
                              uint vid[[vertex_id]])
{
    VertexOut out;
    float4 position = float4(positionsIn[vid], 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    auto normal = normalize(uniforms.normalMatrix * normals[vid]);
    
    auto intensity = min(abs(dot(normal, light_vert)), 1.0);
    out.frontColor = float4(1.0, 0, 0, 1.0) * intensity;
    out.backColor = float4(0.0, 1.0, 0, 1.0) * intensity;
    //out.frontColor = Lighting(uniforms.lightSource, uniforms.frontMaterial, normal);
    //out.backColor = Lighting(uniforms.lightSource, uniforms.backMaterial, normal);
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               bool is_front_face [[ front_facing ]],
                               constant Uniforms & uniforms [[ buffer(0) ]])
{
    float4 color;
    
    if(is_front_face){
        color = in.frontColor;
    }else{
        color = in.backColor;
    }
    
    return color;
}
