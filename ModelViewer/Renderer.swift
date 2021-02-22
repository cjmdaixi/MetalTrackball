//
//  Renderer.swift
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/24.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = ((MemoryLayout<Uniforms>.size + 255) / 256) * 256

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var modelMatrix: matrix_float4x4 = matrix_float4x4(1)
    
    var trackballSize: Float = 1.0
    var rotationSpeed: Float = 3
    var translationSpeed: Float = 0.1
    var scaleSpeed: Float = 0.5
    var screenSize: CGSize!
    
    var camera: Camera!
    
    var vertexBuffer: MTLBuffer!
    var normalBuffer: MTLBuffer!
    
    var plyHeader: PLYHeader!
    var plyHeaders = [String: PLYHeader]()
    
    func projectToTrackball(_ screenCoords: CGPoint) -> simd_float3 {
        let sx = Float(screenCoords.x), sy = Float(screenSize.height - screenCoords.y)
        
        let p2d = simd_float2(x: sx / Float(screenSize.width) - 0.5,
                              y: sy / Float(screenSize.height) - 0.5)
        
        var z:Float = 0.0
        let r2 = trackballSize * trackballSize
        if simd_length_squared(p2d) <= r2 * 0.5 {
            z = sqrt(r2 - simd_length_squared(p2d))
        }
        else {
            z = r2 * 0.5 / simd_length(p2d)
        }
        
        return simd_float3(p2d, z)
    }
    
    func createRotation(firstPoint: CGPoint, nextPoint: CGPoint) -> simd_quatf{
        let lastPos3D = simd_normalize(projectToTrackball(firstPoint))
        let currPos3D = simd_normalize(projectToTrackball(nextPoint))
        
        // Compute axis of rotation:
        let dir = simd_normalize(simd_cross(lastPos3D, currPos3D))
        
        // Approximate rotation angle:
        let dot = simd_dot(lastPos3D, currPos3D)
        let clamped = simd_clamp(dot, -1, 1)
        let angle = acos(clamped)
        
        return simd_quatf(angle: angle * rotationSpeed, axis: dir)
    }
    
    func createTranslation(firstPoint: CGPoint, nextPoint: CGPoint) -> simd_float3{
        let firstPos2D = simd_float4(Float(firstPoint.x), Float(-firstPoint.y), 0, 1)
        let currPos2D = simd_float4(Float(nextPoint.x), Float(-nextPoint.y), 0, 1)
        let mvm = camera.projectionMatrix * camera.viewMatrix
        let inverse_mvm = simd_inverse(mvm)
        let firstPos3D = simd_mul(inverse_mvm, firstPos2D)
        let currPos3D = simd_mul(inverse_mvm, currPos2D)
        let trans_vec = (currPos3D - firstPos3D) * self.translationSpeed * (camera.distance / 8)
        return simd_float3(trans_vec.x, trans_vec.y, trans_vec.z)
    }
    
    func load(ply fileUrl: URL){
        let contains = self.plyHeaders.contains{$0.key == fileUrl.path}
        if contains{
            plyHeader = self.plyHeaders[fileUrl.path]
        }
        else{
            guard let filePointer:UnsafeMutablePointer<FILE> = fopen(fileUrl.path,"r") else {
                preconditionFailure("Could not open file at \(fileUrl.absoluteString)")
            }
            if let ph = getPlyHeader(from: filePointer){
                plyHeader = ph
                let _ = getPlyVertices(from: filePointer, header: &plyHeader)
                let _ = getPlyFaces(from: filePointer, header: &plyHeader)
                self.plyHeaders[fileUrl.path] = plyHeader
            }
            else{
                return
            }
        }
        
        vertexBuffer = device.makeBuffer(bytes: plyHeader.vertices,
                                         length: MemoryLayout<simd_float3>.stride * plyHeader.faceCount * 3,
                                         options: .cpuCacheModeWriteCombined)
        
        normalBuffer = device.makeBuffer(bytes: plyHeader.normals,
                                         length: MemoryLayout<simd_float3>.stride * plyHeader.faceCount * 3,
                                         options: .cpuCacheModeWriteCombined)
        
        modelMatrix = matrix4x4_translation(-plyHeader.modelCenter.x,
                                            -plyHeader.modelCenter.y,
                                            -plyHeader.modelCenter.z)
    }
    
    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        metalKitView.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state
                
        camera = Camera()
        
        super.init()
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
    }
    
    private func updateState() {
        let pm = camera.projectionMatrix
        let mvm = camera.viewMatrix
        uniforms[0].projectionMatrix = pm!
        
        uniforms[0].modelViewMatrix = simd_mul(mvm!, modelMatrix)
        var mat3Rows = simd_float3x3()
        for i in 0...2{
            for j in 0...2{
                mat3Rows[i, j] = uniforms[0].modelViewMatrix[i, j]
            }
        }
        uniforms[0].normalMatrix = simd_transpose(simd_inverse(mat3Rows))
        uniforms[0].distance = camera.distance
        
        let viewportMatrixRows = [
            simd_float4(Float(screenSize.width) / 2, 0, 0, 0 + Float(screenSize.width) / 2),
            simd_float4(0, Float(screenSize.height) / 2, 0, 0 + Float(screenSize.height) / 2)
        ]
        uniforms[0].viewportMatrix = matrix_float4x2(rows: viewportMatrixRows)
        
        uniforms[0].lightSource.position = simd_float3(0.6, 0.6, 1.0)
        uniforms[0].lightSource.ambient = simd_float4(0.175, 0.175, 0.175, 1.0)
        uniforms[0].lightSource.diffuse = simd_float4(0.6, 0.6, 0.6, 1.0)
        uniforms[0].lightSource.specular = simd_float4(0.95, 0.95, 0.95, 1.0)
        
        uniforms[0].frontMaterial.ambient = simd_float4(0.19216, 0.52941, 0.80784, 1.0)
        uniforms[0].frontMaterial.diffuse = simd_float4(0.19216, 0.52941, 0.80784, 1.0)
        uniforms[0].frontMaterial.specular = simd_float4(0.19216, 0.52941, 0.80784, 1.0)
        uniforms[0].frontMaterial.shininess = 9
        
        uniforms[0].backMaterial.ambient = simd_float4(0.02745, 0.08627, 0.13725, 1.0)
        uniforms[0].backMaterial.diffuse = simd_float4(0.2, 0.2, 0.2, 1.0)
        uniforms[0].backMaterial.specular = simd_float4(0.398, 0.398, 0.398, 1.0)
        uniforms[0].backMaterial.shininess = 5
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        if vertexBuffer == nil{
            return
        }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor){
                
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                
                renderEncoder.pushDebugGroup("Draw Box")
                
                renderEncoder.setCullMode(.none)
                
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(pipelineState)
                
                renderEncoder.setDepthStencilState(depthState)
                
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.setVertexBuffer(normalBuffer, offset: 0, index: 1)
                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index:2)
                
                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: 0)
                
                //rendering...
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: plyHeader.faceCount * 3)
                
                renderEncoder.popDebugGroup()
                
                renderEncoder.endEncoding()
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        screenSize = UIScreen.main.bounds.size
        let aspect = Float(screenSize.width) / Float(screenSize.height)
        camera.aspectRatio = aspect
    }
}
