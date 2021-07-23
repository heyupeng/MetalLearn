//
//  Render.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

import UIKit
import MetalKit
import GLKit


/// vector_float3 的内存大小为16。可使用 MTLPackedFloat3
public struct CTMFloat3 {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
}

extension CTMFloat3: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(x), \(y), \(z))"
    }
}

extension MTLPackedFloat3: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(x), \(y), \(z))"
    }
}

struct Vertex2D {
    var position: vector_float2
    var coord: vector_float2
}

struct Vertex3D {
    var position: CTMFloat3;
    var normal: CTMFloat3;
    var coord: vector_float2;
};

struct MatrixContants {
    var modelViewProjectionMatrix: matrix_float4x4 = matrix_identity_float4x4
}

class Render: NSObject, MTKViewDelegate {
    
    struct Axis {
        static var xFlag: Bool = false
        static var yFlag: Bool = false
        static var zFlag: Bool = false
        
        static var x: Float = 0 // .50 * .pi
        static var y: Float = 0 // .25 * .pi
        static var z: Float = 0 // .25 * .pi
        
    }
    
    var view: MTKView!
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let fence: MTLFence!
    var drawableSize: CGSize = CGSize.zero
    
    var pipelineState: MTLRenderPipelineState?
    
    var depthStencilState: MTLDepthStencilState?
    
    // 定点数据
    var vertexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    
    var indexBuffer: MTLBuffer?
    var indexCount: Int = 0
    var indexType: MTLIndexType = .uint32
    
    // 图元类型
    var primitiveType: MTLPrimitiveType = .triangle
    
    var texture: MTLTexture?
    
    var imageHeap: MTLHeap?
    
    init?(mtkView: MTKView) {
        self.view = mtkView
        
        /// 创建 Metal device。
        if let defaultDevice = MTLCreateSystemDefaultDevice() {
            device = defaultDevice
            fence = device.makeFence()
        }
        else {
            print("Error: Metal is not supported")
            return nil
        }
        
        /// 创建命令队列。
        if let queue = device.makeCommandQueue() {
            commandQueue = queue
        } else {
            print("Error: Command queue is not supported")
            return nil
        }
        
        super.init()
        
        view.device = device
        view.delegate = self
        
        view.depthStencilPixelFormat = .depth32Float
        
        (vertexBuffer, vertexCount, indexBuffer, indexCount) = buildVertex2D(device)
        
        loadTexture()
        
        setupVertex3D()
        
        /*
         当绘制命令编码器设置深度模型时，`renderEncoder.setDepthStencilState(state)`；
         
         运行报错：
         validateDepthStencilState:4140: failed assertion `MTLDepthStencilDescriptor sets depth test but MTLRenderPassDescriptor has a nil depthAttachment texture'
         
         断点停留位置：
         `renderEncoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer!, indexBufferOffset: 0)`
         
         解决方法：
         https://developer.apple.com/forums/thread/45486?answerId=180131022#180131022
         Are you configuring the depthStencilPixelFormat of your MTKView? It should be set to
         .Depth32Float_Stencil8 or similar. If you leave this set to the default (.Invalid), the view won't create a depth texture for you.
         
         mtkView.depthStencilPixelFormat 在模拟器上为默认值(.invalid)，真机上为 .depth32Float 。
         view.depthStencilPixelFormat = .depth32Float_Stencil8
         */
        
        view.depthStencilPixelFormat = .depth32Float

        buildPipelineDescriptor()
        
        buildDepthStencilDescriptor()
        
    }
    
    ///
    /// - Parameter device: Metal device
    /// - Returns: (vertexBuffer, vertexCount, indexBuffer, indexCount )
    func buildVertex2D(_ device : MTLDevice) -> (MTLBuffer, Int, MTLBuffer?, Int)
    {
        // left-up, right-up, l-d, r-d
        let v1 = Vertex2D(position: [-0.5,  0.5], coord: [0.0, 0.0])
        let v2 = Vertex2D(position: [ 0.5,  0.5], coord: [1.0, 0.0])
        let v3 = Vertex2D(position: [-0.5, -0.5], coord: [0.0, 1.0])
        let v4 = Vertex2D(position: [ 0.5, -0.5], coord: [1.0, 1.0])
    
        var vertexs: [Vertex2D] = [
//            v1, v2, v3, v4
            v1, v2, v4,
            v1, v4, v3
        ]
        
        let vertexLength = vertexs.count * MemoryLayout<Vertex2D>.size
        let vertexCount = vertexs.count
        
        let vertexBuffer = device.makeBuffer(bytes: &vertexs, length: vertexLength, options: MTLResourceOptions.storageModeShared)
        
        var indexs : [Float] = [
            // 前
            0, 3, 1,
            0, 2, 3,
            // 后
            4, 7, 5,
            4, 6, 7,
            // 上
            8, 11, 9,
            8, 10, 11,
            // 下
            12, 15, 13,
            12, 14, 15,

            16, 19, 17,
            16, 18, 19,

            20, 23, 21,
            20, 22, 23
        ]
        
        let indexCount = indexs.count
        let indexLength = indexs.count * MemoryLayout<Float>.size
        let indexBuffer = device.makeBuffer(bytes: &indexs, length: indexLength, options: MTLResourceOptions.storageModeShared)
        
        if true {
//            return (vertexBuffer!, vertexCount, nil, 0)
        }
        
        return (vertexBuffer!, vertexCount, indexBuffer!, indexCount)
    }
    
    func buildPipelineDescriptor() {
        let lib = device.makeDefaultLibrary()
        let vertexFunc = lib?.makeFunction(name: "vertexFunc_mesh")
        let fragmentFunc = lib?.makeFunction(name: "fragmentFunc")
                
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Drawable Pipeline";
        pipelineDescriptor.sampleCount = view.sampleCount;
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
//        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
        
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Unable to compile render pipeline state")
        }
    }
    
    // 3d变换需要建立深度模板描述符
    func buildDepthStencilDescriptor() {
        
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.label = "Depth Stencil";
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
            
        if depthStencilState == nil {
            print("Unable to compile depth stencil state")
        }
    }
    
    func buildSamplerState(_ device: MTLDevice,
                                 _ addressMode: MTLSamplerAddressMode,
                                 _ filter: MTLSamplerMinMagFilter) -> MTLSamplerState {
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    func loadTexture(_ assets: Bool = false) {
        if assets {
            let name = "checkerboard"
            do {
                texture = try Self.buildTexture(assetsName: name, device)
            } catch {
                print("Unable to load texture in assets named \(name)")
            }
            return
        }
        
        let fileName = "Image3.jpg"
        do {
            texture = try Self.buildTexture(fileName: fileName, device)
        } catch {
            print("Unable to load texture named \(fileName)")
        }
    }
    
    func setupVertex3D() {
        /// Vertex
        let segment = uint(1)
        let segments = vector_uint3(segment, segment, segment)
        let allocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh(boxWithExtent: vector_float3(1, 1, 1), segments: segments, inwardNormals: false, geometryType: .triangles, allocator: allocator)
        
        do {
            let mesh = try MTKMesh(mesh: mdlMesh, device: device)
            let vertexMeshBuffer = mesh.vertexBuffers[0]
            let submesh = mesh.submeshes[0]
            
            vertexBuffer = vertexMeshBuffer.buffer
            vertexCount = vertexMeshBuffer.length
                        
            indexCount = submesh.indexCount
            indexType = submesh.indexType
            indexBuffer = submesh.indexBuffer.buffer
            
            primitiveType = submesh.primitiveType
            
            let vs = self.convertVertex(form: vertexMeshBuffer.buffer, type: Vertex3D.self)
            
            print("MTKMesh")
        } catch {
            print("Unable to MTKMesh")
        }
        
    }
    // 三维
    func setMatrx(encoder: MTLRenderCommandEncoder, index: Int) {
        let timestep = 1.0 / Float(view.preferredFramesPerSecond)

        if Self.Axis.xFlag == true { Self.Axis.x += timestep }
        if Self.Axis.yFlag == true { Self.Axis.y += timestep }
        if Self.Axis.zFlag == true { Self.Axis.z += timestep }
        
        /// 投影
        let size = view.bounds.size
        let aspectRatio = Float(size.width / size.height)
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90), aspectRatio, 0.1, 100)
        
        /// 模型
        var modelMatrix = GLKMatrix4Identity
//        modelMatrix = GLKMatrix4Translate(modelMatrix, 0.0, 0.0, -2.0);
        
        modelMatrix = GLKMatrix4RotateZ(modelMatrix, Self.Axis.z)
        modelMatrix = GLKMatrix4RotateY(modelMatrix, Self.Axis.y)
        modelMatrix = GLKMatrix4RotateX(modelMatrix, Self.Axis.x)
        
        modelMatrix = GLKMatrix4RotateX(modelMatrix, .pi * 0.25 * -1)
        modelMatrix = GLKMatrix4RotateY(modelMatrix, .pi * 0.25 * -1)
        
        /// 视觉。鸟瞰视角
        let viewMatrix = GLKMatrix4MakeLookAt(0, 0, 2, 0, 0, 0, 0, 1, 0)
        
        /// 合并模型 - 视图 - 投影
        var matrix =  modelMatrix
        matrix = GLKMatrix4Multiply(viewMatrix, matrix)
        matrix = GLKMatrix4Multiply(projectionMatrix, matrix)
        
        var contants = MatrixContants()
        contants.modelViewProjectionMatrix = GLKMatrix4ToMatrix4x4(matrix)
        
        encoder .setVertexBytes(&contants, length: MemoryLayout<MatrixContants>.size, index: index)
    }
    
    // MARK: Class func
    
    class func buildTexture(assetsName name: String, _ device: MTLDevice) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        let assetName = NSDataAssetName(name)
        let asset = NSDataAsset.init(name: assetName)
        if let data = asset?.data {
//            return try textureLoader.newTexture(with: data, options: [:])
            // Swift 4.0 +
            return try textureLoader.newTexture(data: data, options: [:])
        } else {
            fatalError("Could not load image \(name) from an asset catalog in the main bundle")
        }
    }
    
    class func buildTexture(fileName: String, _ device: MTLDevice) throws -> MTLTexture {
        let cmps = fileName.split(separator: ".")
        if cmps.count < 2 {
            let desc = "No file extension and could not load image \(fileName)"
            let info = [NSLocalizedDescriptionKey: desc]
            let err = NSError(domain: "com.loadTexture", code: 1, userInfo: info)
            throw err
        }
        
        let url = Bundle.main.url(forResource: String(describing: cmps.first!), withExtension: String(describing: cmps.last!))
        if url == nil {
            let desc = "Could not load image \(fileName) from an asset catalog in the main bundle"
            let info = [NSLocalizedDescriptionKey: desc]
            let err = NSError(domain: "com.loadTexture", code: 2, userInfo: info)
            throw err
//            fatalError("Could not load image \(name) from an asset catalog in the main bundle")
        }
        
        var SRGB = false
        #if TARGET_IOS
        let feature = MTLFeatureSet.iOS_GPUFamily3_v1
        SRGB = device.supportsFeatureSet(feature)
        #elseif TARGET_TVOS
        let feature = feature = MTLFeatureSet.tvOS_GPUFamily1_v2
        SRGB = device.supportsFeatureSet(feature)
        #endif
        
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [.SRGB: SRGB]
        return try textureLoader.newTexture(URL: url!, options: options)
    }
    
    class func buildSamplerStateWithDevice(_ device: MTLDevice,
                                           addressMode: MTLSamplerAddressMode,
                                           filter: MTLSamplerMinMagFilter) -> MTLSamplerState
    {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
//        return device.makeSamplerState(descriptor: samplerDescriptor)
        // Swift 4.0 +
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    func convertVertex<T>(form buffer: MTLBuffer, type: T.Type) -> [T] {
        var p = pthread_mutex_t()
        pthread_mutex_lock(&p)
        
        let count = buffer.length / MemoryLayout<T>.size
        let rawBuffer = UnsafeRawPointer(buffer.contents())
        let typePointer = rawBuffer.bindMemory(to: T.self, capacity: count)
        let typeBuffer = UnsafeBufferPointer<T>(start: typePointer, count: count)
        
        let ts = [T](typeBuffer)
        
        pthread_mutex_unlock(&p)
        print("\(T.self) count is \(ts.count)")
        return ts
    }
    
    // MARK: MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("Tips: The drawable size of mtkView will change \(size)")
        drawableSize = size
    }
    
    func draw(in view: MTKView) {
        /// 绘制描述符
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        
        ///
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        /// 绘制命令编码器
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        if let renderEncoder = renderEncoder {
            // To do.
            
            renderEncoder.setFrontFacing(.counterClockwise)
            
            if let state = depthStencilState {
                renderEncoder.setDepthStencilState(state)
            }
            
            if let state = pipelineState {
                renderEncoder.setRenderPipelineState(state)
            }

//            renderEncoder.pushDebugGroup("DrawQuad")
//            renderEncoder.waitForFence(fence!, before: .fragment)
            
            renderEncoder.setFragmentTexture(texture, index: 0)
            
            setMatrx(encoder: renderEncoder, index: 1)
            
//            var scale: vector_float2 = vector_float2(1.0, 1.0)
//            let drawableRate = view.drawableSize.width / view.drawableSize.height
//            let textureRate = CGFloat(texture!.width) / CGFloat(texture!.height)
//            if drawableRate > textureRate {
//                scale.x = Float(textureRate / drawableRate)
//            } else {
//                scale.y = Float(drawableRate / textureRate)
//            }
//            renderEncoder.setVertexBytes(&scale, length: MemoryLayout<vector_float2>.size, index: 1)
            
            
            /// Vertex
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

            if indexBuffer != nil, indexCount > 0 {
                renderEncoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer!, indexBufferOffset: 0)
            } else {
                renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: vertexCount)
            }
            
//            renderEncoder.updateFence(fence!, after: .fragment)
//            renderEncoder.popDebugGroup()
            
            /// 结束编码
            renderEncoder.endEncoding()
            /// 显示可绘制内容
            if let drawable = view.currentDrawable {
                commandBuffer?.present(drawable)
            }
        }
        
        /// 提交
        commandBuffer?.commit()
    }
    
}
