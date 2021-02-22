//
//  Camera.swift
//  Point Cloud
//
//  Created by Robert-Hein Hooijmans on 21/12/16.
//  Copyright © 2016 Robert-Hein Hooijmans. All rights reserved.
//

import Foundation
import UIKit

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: simd_float3) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(simd_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         simd_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         simd_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         simd_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(simd_float4(1, 0, 0, 0),
                                         simd_float4(0, 1, 0, 0),
                                         simd_float4(0, 0, 1, 0),
                                         simd_float4(translationX, translationY, translationZ, 1)))
}

func matrix4x4_scale(_ scaleX: Float, _ scaleY: Float, _ scaleZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(simd_float4(scaleX, 0, 0, 0),
                                         simd_float4(0, scaleY, 0, 0),
                                         simd_float4(0, 0, scaleZ, 0),
                                         simd_float4(0, 0, 0, 1)))
}


func matrix4x4_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(simd_float4(xs,  0, 0,   0),
                                         simd_float4( 0, ys, 0,   0),
                                         simd_float4( 0,  0, zs, -1),
                                         simd_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

class Camera {
    var projectionMatrix: simd_float4x4!
    var viewMatrix: simd_float4x4!
    var distance: Float = 8{
        didSet{
            let reverseTranslationMatrix = translationMatrix.inverse
            viewMatrix = simd_mul(reverseTranslationMatrix, viewMatrix)
            translationMatrix = matrix4x4_translation(0, 0, -distance)
            viewMatrix = simd_mul(translationMatrix, viewMatrix)
            
        }
    }
    
    var translationMatrix: simd_float4x4!
    
    var rotationMatrix = matrix4x4_rotation(radians: 0, axis: simd_float3(0, 0, 1)){
        didSet{
            let reverseTranslationMatrix = translationMatrix.inverse
            viewMatrix = simd_mul(reverseTranslationMatrix, viewMatrix)
            let reverseRotationMatrix = oldValue.inverse
            viewMatrix = simd_mul(reverseRotationMatrix, viewMatrix)
            viewMatrix = simd_mul(rotationMatrix, viewMatrix)
            viewMatrix = simd_mul(translationMatrix, viewMatrix)
        }
    }
    
    var fov: Float = 65
    var aspectRatio: Float = 1.0{
        didSet{
            projectionMatrix = matrix4x4_perspective_right_hand(
                fovyRadians: radians_from_degrees(fov),
                aspectRatio:aspectRatio,
                nearZ: nearZ, farZ: farZ
            )
        }
    }
    var nearZ: Float = 0.001
    var farZ: Float = 1000.0
    
    var matrix: simd_float4x4 {
        simd_mul(projectionMatrix, viewMatrix)
    }
    
    init(){
        translationMatrix = matrix4x4_translation(0, 0, -distance)
        
        viewMatrix = simd_mul(translationMatrix, rotationMatrix)
        projectionMatrix = matrix4x4_perspective_right_hand(
            fovyRadians: radians_from_degrees(fov),
            aspectRatio:aspectRatio,
            nearZ: nearZ, farZ: farZ
        )
    }
}
