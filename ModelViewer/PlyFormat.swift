//
//  PlyFormat.swift
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/27.
//

import Foundation
import Darwin

struct PLYHeader{
    let vertexCount: Int
    let faceCount: Int
    var modelCenter: simd_float3!
    var indexedVertices: Array<simd_float3>!
    var indexedNormals: Array<simd_float3>!
    var vertices: Array<simd_float3>!
    var normals: Array<simd_float3>!
}

// common ply header:
// ply
// format binary_little_endian 1.0
// comment VCGLIB generated
// element vertex 71020
// property float x
// property float y
// property float z
// element face 140920
// property list uchar int vertex_indices
// end_header
func getPlyHeader(from filePointer: UnsafeMutablePointer<FILE>) -> PLYHeader? {
    var lineCap: Int = 0
    var vertexCount: Int = 0
    var faceCount: Int = 0
    
    var magicTokenVerified = false
    var str: String
    
    repeat{
        var lineByteArrayPointer: UnsafeMutablePointer<CChar>? = nil
        defer {
            lineByteArrayPointer?.deallocate()
        }
        
        let bytesRead = getline(&lineByteArrayPointer, &lineCap, filePointer)
        if bytesRead <= 0{
            return nil
        }
        str = String(cString: lineByteArrayPointer!)
            .trimmingCharacters(in: .newlines)
        if !magicTokenVerified {
            if str != "ply"{
                return nil
            }else{
                magicTokenVerified = true
                continue
            }
        }
        
        if str.starts(with: "comment "){
            continue
        }
        if str.starts(with: "element vertex "){
            let parts = str.components(separatedBy: " ")
            if parts.count != 3{
                return nil
            }
            guard let vc = Int(parts[2]) else{
                return nil
            }
            vertexCount = vc
        }
        else if str.starts(with: "element face "){
            let parts = str.components(separatedBy: " ")
            if parts.count != 3{
                return nil
            }
            guard let fc = Int(parts[2]) else{
                return nil
            }
            faceCount = fc
        }
    }while(str != "end_header")
    return PLYHeader(vertexCount: vertexCount, faceCount: faceCount)
}

func getPlyVertices(from filePointer: UnsafeMutablePointer<FILE>, header: inout PLYHeader) -> [simd_float3] {
    var vertices = Array<simd_float3>(repeating: simd_float3.zero, count: header.vertexCount)
    
    let buf = UnsafeMutablePointer<Float32>.allocate(capacity: 3)
    defer {
        buf.deinitialize(count: 3)
        buf.deallocate()
    }
    buf.initialize(to: Float32.zero)
    
    var vertices_center = simd_float3(0, 0, 0)
    
    for i in 0..<header.vertexCount{
        fread(buf, MemoryLayout<Float32>.size * 3, 1, filePointer)
        vertices[i] = simd_float3(buf[0], buf[1], buf[2])
        vertices_center += vertices[i]
    }
    header.modelCenter = simd_float3(vertices_center.x / Float(header.vertexCount),
                                     vertices_center.y / Float(header.vertexCount),
                                     vertices_center.z / Float(header.vertexCount))
    header.indexedVertices = vertices
    header.indexedNormals = Array<simd_float3>(repeating: simd_float3.zero, count: header.vertexCount)
    return vertices
}

func getPlyFaces(from filePointer: UnsafeMutablePointer<FILE>, header: inout PLYHeader) -> [simd_int3] {
    var faces = Array<simd_int3>(repeating: simd_int3.zero, count: header.faceCount)
    
    var indexCount: UInt8 = 0
    let faceIndexBuf = UnsafeMutablePointer<Int32>.allocate(capacity: Int(indexCount))
    faceIndexBuf.initialize(to: 0)
    
    header.vertices = Array<simd_float3>(repeating: simd_float3.zero, count: header.faceCount * 3)
    header.normals = Array<simd_float3>(repeating: simd_float3.zero, count: header.faceCount * 3)
        
    var indexedNormalsCount = Array<UInt8>(repeating: UInt8.zero, count: header.vertexCount)
    
    for i in 0..<header.faceCount{
        fread(&indexCount, MemoryLayout<UInt8>.size, 1, filePointer)
        
        fread(faceIndexBuf, MemoryLayout<Int32>.size, Int(indexCount), filePointer)
        faces[i] = simd_int3(faceIndexBuf[0], faceIndexBuf[1], faceIndexBuf[2])
        
        let p0 = header.indexedVertices[Int(faceIndexBuf[0])]
        let p1 = header.indexedVertices[Int(faceIndexBuf[1])]
        let p2 = header.indexedVertices[Int(faceIndexBuf[2])]
        let v0 = p1 - p0;
        let v1 = p2 - p0;
        let n = simd_normalize(simd_cross(v0, v1));
        header.vertices[i * 3] = p0
        header.vertices[i * 3 + 1] = p1
        header.vertices[i * 3 + 2] = p2
        header.normals[i * 3] = n
        header.normals[i * 3 + 1] = n
        header.normals[i * 3 + 2] = n
        
        header.indexedNormals[Int(faceIndexBuf[0])] += n
        header.indexedNormals[Int(faceIndexBuf[1])] += n
        header.indexedNormals[Int(faceIndexBuf[2])] += n
        
        indexedNormalsCount[Int(faceIndexBuf[0])] += 1
        indexedNormalsCount[Int(faceIndexBuf[1])] += 1
        indexedNormalsCount[Int(faceIndexBuf[2])] += 1
    }
    faceIndexBuf.deallocate()
    
    for i in 0..<header.vertexCount{
        let count = Float(indexedNormalsCount[i])
        let average = simd_float3(header.indexedNormals[i].x / count, header.indexedNormals[i].y / count, header.indexedNormals[i].z / count)
        header.indexedNormals[i] = average
    }
    return faces
}

