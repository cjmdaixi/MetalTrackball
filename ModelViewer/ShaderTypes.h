//
//  ShaderTypes.h
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/24.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define NONPERSPECTIVE [[center_no_perspective]]
#else
#import <Foundation/Foundation.h>
#define NONPERSPECTIVE
#endif

#include <simd/simd.h>

typedef struct
{
    simd_float3 position;
    simd_float4 ambient;
    simd_float4 diffuse;
    simd_float4 specular;
} LightSource;

typedef struct
{
    simd_float4 ambient;
    simd_float4 diffuse;
    simd_float4 specular;
    float shininess;
} Material;

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x2 viewportMatrix;
    float distance;
    LightSource lightSource;
    Material frontMaterial;
    Material backMaterial;
} Uniforms;

#endif /* ShaderTypes_h */

