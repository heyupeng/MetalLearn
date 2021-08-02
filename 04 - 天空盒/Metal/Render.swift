//
//  Render.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

import UIKit
import MetalKit
import GLKit

struct Vertex2D {
    var position: vector_float2 = [0, 0]
    var coord: vector_float2 = [0, 0]
    
}

struct PackedVertex3D {
    var position: CTMFloat3;
    var normal: CTMFloat3;
    var coord: packed_float2;
    
    init(_ position: CTMFloat3 = CTMFloat3.zero, _ normal: CTMFloat3 = .zero, _ coord: vector_float2 = [0,0]) {
        self.position = position
        self.normal = normal
        self.coord = coord
    }
}

struct Vertex3D
{
    var position: vector_float3
    var normal: vector_float3
    
    
    init(_ position: vector_float3 = vector_float3(0, 0, 0), _ normal: vector_float3 = vector_float3(0, 0, 0)) {
        self.position = position
        self.normal = normal
        
    }
}

struct Triangle {
    var v0: Vertex3D
    var v1: Vertex3D
    var v2: Vertex3D
    var zFlag: Float = 0
    
    init(v0: Vertex3D, v1: Vertex3D, v2: Vertex3D, zFlag: Float = 0) {
        self.v0 = v0
        self.v1 = v1
        self.v2 = v2
        self.zFlag = zFlag
    }
}

func sphere_create(segment: UInt) -> [Vertex3D] {
    
    let cv = [
        Vertex3D([0, 0, 1], [0, 0, 1]),
        Vertex3D([0, 0, -1], [0, 0,-1]),
        Vertex3D([1, 0, 0], [1, 0, 0]),
        Vertex3D([0, 1, 0], [0, 1, 0]),
        Vertex3D([-1, 0, 0], [-1, 0, 0]),
        Vertex3D([0, -1, 0], [0, -1, 0]),
    ]
    
    var reader: [Triangle] = []
    var writer: [Triangle] = []
    
    reader = [
        Triangle(v0: cv[0], v1: cv[2], v2: cv[3]),
        Triangle(v0: cv[0], v1: cv[3], v2: cv[4]),
        Triangle(v0: cv[0], v1: cv[4], v2: cv[5]),
        Triangle(v0: cv[0], v1: cv[5], v2: cv[2]),
        
        Triangle(v0: cv[1], v1: cv[2], v2: cv[3], zFlag: -1),
        Triangle(v0: cv[1], v1: cv[3], v2: cv[4], zFlag: -1),
        Triangle(v0: cv[1], v1: cv[4], v2: cv[5], zFlag: -1),
        Triangle(v0: cv[1], v1: cv[5], v2: cv[2], zFlag: -1),
    ]
    
    let midNormal = { (v0: Vertex3D, v1: Vertex3D) -> Vertex3D in
        var position = (v0.position + v1.position) * 0.5;
        position = normalize(position)
        return Vertex3D(position, position)
    }
    
    for _ in 0..<segment {
        writer.removeAll()
        
        for index in 0..<reader.count {
            let t = reader[index]
            
            let v01 = midNormal(t.v0, t.v1)
            let v02 = midNormal(t.v0, t.v2)
            let v12 = midNormal(t.v1, t.v2)
            // 逆时针重绘三角形
            writer.append(Triangle(v0: t.v0, v1: v01, v2: v02, zFlag: t.zFlag))
            writer.append(Triangle(v0: t.v1, v1: v12, v2: v01, zFlag: t.zFlag))
            writer.append(Triangle(v0: t.v2, v1: v02, v2: v12, zFlag: t.zFlag))
            writer.append(Triangle(v0: v01, v1: v12, v2: v02, zFlag: t.zFlag))
        }
        reader = writer
    }
            
    var vertexs: [Vertex3D] = []
    for index in 0..<reader.count {
        let tri = reader[index]
        
        vertexs.append(tri.v0)
        vertexs.append(tri.v1)
        vertexs.append(tri.v2)
    }
    return vertexs
}

struct MeshModel {
    var vertexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    
    var indexBuffer: MTLBuffer?
    var indexCount: Int = 0
    var indexType: MTLIndexType = .uint32
    
    var primitiveType: MTLPrimitiveType = .triangle
};

struct MatrixContants {
    var modelViewProjectionMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    var projectionMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    var viewMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    var modelMatrix: matrix_float4x4 = matrix_identity_float4x4
    var modelInvMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    /// viewMatrix 逆矩阵
    var viewInvMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    var projectionInvMatrix: matrix_float4x4 = matrix_identity_float4x4
    var projector: vector_float3 = vector_float3(0, 0, 0)
    
    var normalMatrix: matrix_float3x3 = matrix_identity_float3x3
}

class Render: NSObject, MTKViewDelegate {
    
    struct Axis {
        static var isOn: simd_int3 = .zero
        
        static var eye: simd_float3 = simd_float3.zero
        
        static var isOnForSphere: simd_int3 = .zero
        static var sphere: simd_float3 = simd_float3.zero
    }
    
    let semaphore = DispatchSemaphore(value: 1)
    
    var view: MTKView!
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let fence: MTLFence!
    var drawableSize: CGSize = CGSize.zero
    
    var pipelineState: MTLRenderPipelineState?
    
    var skyDomeState: MTLRenderPipelineState?
    var skySpheresState: MTLRenderPipelineState?
    
    var depthStencilState: MTLDepthStencilState?
    
    // 定点数据
    var vertexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    var indexBuffer: MTLBuffer?
    var indexCount: Int = 0
    var indexType: MTLIndexType = .uint32
    
    var spheresMesh: MeshModel = MeshModel()
    
    // 图元类型
    var primitiveType: MTLPrimitiveType = .triangle
    
    var texture: MTLTexture?
    
    var skyTexture: MTLTexture?
    
    var contants: MatrixContants = MatrixContants()
    
    var _colorTexture: MTLTexture?
    var _depthTexture: MTLTexture?;
    
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
        
        setup()
    }
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
     
     mtkView.depthStencilPixelFormat 在模拟器上为默认值(.invalid)，真机上为 .depth32Float 。此为深度像素格式不一致导致错误。
     view.depthStencilPixelFormat = .depth32Float_Stencil8
     */
    
    func setup() {
        view.depthStencilPixelFormat = .depth32Float
        
        (vertexBuffer, vertexCount, indexBuffer, indexCount) = buildVertex2D(device)
        
        loadTexture()
        
        setupPackedVertex3D()
        
        setupSphereVertex3D()
        
        setupSphereVertex3D1()
        
        buildPipelineDescriptor()
        
        buildSkyDomePipelineDescriptor(view, device)

        buildSkySpheresPipelineDescriptor(view, device)
        
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
        let vertexFunc = lib?.makeFunction(name: "vertexFunc")
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
    
    func buildSkyDomePipelineDescriptor(_ view: MTKView, _ device: MTLDevice) {
        let lib = device.makeDefaultLibrary()
        let vertexFunc = lib?.makeFunction(name: "skyDome_vertex")
        let fragmentFunc = lib?.makeFunction(name: "skyDome_fragment")
                
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Pipeline - Sky Dome";
        pipelineDescriptor.sampleCount = view.sampleCount;
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
        
        if view.depthStencilPixelFormat == .stencil8 ||
           view.depthStencilPixelFormat == .depth32Float_stencil8 ||
           view.depthStencilPixelFormat == .x32_stencil8 {
            pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
        }
        
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        do {
            let state = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            skyDomeState = state
        } catch {
            print("Error: Unable to compile render pipeline state")
        }
    }
    
    func buildSkySpheresPipelineDescriptor(_ view: MTKView, _ device: MTLDevice) {
        let lib = device.makeDefaultLibrary()
        let vertexFunc = lib?.makeFunction(name: "sphere_vertex")
        let fragmentFunc = lib?.makeFunction(name: "sphere_fragment")
                
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Pipeline - Sky Spheres";
        pipelineDescriptor.sampleCount = view.sampleCount;
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
        
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        do {
            let state = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            skySpheresState = state
            print("Tip: Finish compiling render pipeline state")
        } catch {
            print("Error: Unable to compile render pipeline state")
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
        
        let skyFileName = "kloppenheim_06.png"
        do {
            skyTexture = try Self.buildTexture(fileName: skyFileName, device)
        } catch {
            print("Unable to load texture named \(skyFileName)")
        }
    }
    
    func setupPackedVertex3D() {
        /// Vertex
        let segment = uint(4)
        let segments = vector_uint3(segment, segment, segment)
        let allocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh(boxWithExtent: vector_float3(1, 1, 1), segments: segments, inwardNormals: false, geometryType: .triangles, allocator: allocator)
        
        do {
            let mesh = try MTKMesh(mesh: mdlMesh, device: device)
            let vertexMeshBuffer = mesh.vertexBuffers[0]
            let submesh = mesh.submeshes[0]
            
            var vs = self.convertVertex(form: vertexMeshBuffer.buffer, type: PackedVertex3D.self)

            vertexBuffer = vertexMeshBuffer.buffer
            vertexCount = vertexMeshBuffer.length
                       
            indexCount = submesh.indexCount
            indexType = submesh.indexType
            indexBuffer = submesh.indexBuffer.buffer
            
            primitiveType = submesh.primitiveType
            
            print("MTKMesh")
        } catch {
            print("Unable to MTKMesh")
        }
        
    }
    
    func setupSphereVertex3D() {
        var vertexCount: UInt32 = 0
        guard let opaquePointer = generate_sphere_data(&vertexCount) else {
            return
        }

        let pointer = UnsafeRawPointer(opaquePointer)
        let vertexLength = Int(vertexCount) * 32
        let vertexs = memory_convert(form: pointer, length: vertexLength, type: Vertex3D.self)

        spheresMesh = MeshModel()
        spheresMesh.vertexBuffer = device.makeBuffer(bytes: vertexs, length: vertexLength, options: .storageModeShared)
        spheresMesh.vertexCount = Int(vertexCount)
    }
    
    func setupSphereVertex3D1() {
        let vertexs: [Vertex3D] = sphere_create(segment: 4)
        let vertexLength = vertexs.count * MemoryLayout<Vertex3D>.size
        
        spheresMesh = MeshModel()
        spheresMesh.vertexBuffer = device.makeBuffer(bytes: vertexs, length: vertexLength  , options: .storageModeShared)
        spheresMesh.vertexCount = vertexs.count
    }
    
    
    // 坐标系变换：投影变换
    // https://zhuanlan.zhihu.com/p/114729671
    // 三维
    func updateMatrx() {
        let timestep: Float = 1.0
        
        if Self.Axis.isOn.x == 1 { Self.Axis.eye.x += timestep }
        if Self.Axis.isOn.y == 1 { Self.Axis.eye.y += timestep }
        if Self.Axis.isOn.z == 1 { Self.Axis.eye.z += timestep }
        
        if Self.Axis.isOnForSphere.x == 1 { Self.Axis.sphere.x += timestep }
        if Self.Axis.isOnForSphere.y == 1 { Self.Axis.sphere.y += timestep }
        if Self.Axis.isOnForSphere.z == 1 { Self.Axis.sphere.z += timestep }
        
        /// 投影
        let size = view.bounds.size
        let aspectRatio = Float(size.width / size.height)
        let axisZ = vector_float2(1, 1000)
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90), aspectRatio, axisZ.x, axisZ.y)
        
        /// 模型
        var modelMatrix = GLKMatrix4Identity
        modelMatrix = GLKMatrix4Translate(modelMatrix, 0.0, 0.0, -5.0);
        modelMatrix = GLKMatrix4Rotate(modelMatrix, GLKMathDegreesToRadians(-Axis.sphere.x), 10, 0, 0)
        modelMatrix = GLKMatrix4Rotate(modelMatrix, GLKMathDegreesToRadians( Axis.sphere.y), 0, 10, 0)
        modelMatrix = GLKMatrix4Rotate(modelMatrix, GLKMathDegreesToRadians(-Axis.sphere.z), 0, 0, 10)
        
        /// 视觉。鸟瞰视角
        var eye = vector_float3(0, 0, 3)        
        eye.x = 10 * sin(GLKMathDegreesToRadians(-Axis.eye.x))
        eye.y = 10 * sin(GLKMathDegreesToRadians( Axis.eye.y))
        eye.z = 10 * cos(GLKMathDegreesToRadians(-Axis.eye.z))
        
        let viewMatrix = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0, 1, 0)
        
        var contants = MatrixContants()
        
        contants.modelMatrix = modelMatrix.matrix4x4()
        contants.modelInvMatrix = contants.modelMatrix.inverse
        
        /// 合并模型 - 视图 - 投影
        var matrix =  modelMatrix
        matrix = GLKMatrix4Multiply(viewMatrix, matrix)

        var isInvertable: Bool = false
        let viewInv = GLKMatrix4Invert(viewMatrix, &isInvertable)
        contants.viewMatrix = GLKMatrix4ToMatrix4x4(viewMatrix)
        contants.viewInvMatrix = GLKMatrix4ToMatrix4x4(viewInv)
        
        contants.normalMatrix = matrix.matrix4x4().matrix3x3().inverse
        
        matrix = GLKMatrix4Multiply(projectionMatrix, matrix)
        contants.modelViewProjectionMatrix = GLKMatrix4ToMatrix4x4(matrix)
        
        var eyePos = vector_float3(0,0,0)
        eyePos.x = projectionMatrix.m11 * axisZ.y * aspectRatio
        eyePos.y = projectionMatrix.m11 * axisZ.y
        eyePos.z = axisZ.y
        
        contants.projector = eyePos
        contants.projectionMatrix = GLKMatrix4ToMatrix4x4(projectionMatrix)
        contants.projectionInvMatrix = GLKMatrix4ToMatrix4x4(GLKMatrix4Invert(matrix, &isInvertable))
        
        
        self.contants = contants
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
    
    func convertVertex<T>(form buffer: MTLBuffer, type: T) -> [T] {
        let rawPointer = buffer.contents()
        let length = buffer.length
        
        return memory_convert(form: rawPointer, length: length, type: T.self)
        
        var p = pthread_mutex_t()
        pthread_mutex_lock(&p)
                
        let size = MemoryLayout<T>.size
        let count = length / size
        let rawBuffer = rawPointer
        
        let typePointer = rawBuffer.bindMemory(to: T.self, capacity: count)
        let typeBuffer = UnsafeBufferPointer<T>(start: typePointer, count: count)
        
        let ts = [T](typeBuffer)
        
        pthread_mutex_unlock(&p)
        print("\(T.self) count is \(ts.count)")
        
        return ts
    }
    
    // MARK: MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("Tip: The drawable size of mtkView will change \(size)")
        drawableSize = size
        
        
        let depthFormat: MTLPixelFormat = view.depthStencilPixelFormat
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthFormat, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
        
        texDesc.usage = .renderTarget

        //  The renderer will not reuse depth, it marks them as memoryless on Apple Silicon devices.
        //  Otherwise the texture must use private memory.
        texDesc.storageMode = .private;
        #if TARGET_MACOS
        if #available(macOS 11, *) {
            // On macOS, the MTLGPUFamilyApple1 enum is only avaliable on macOS 11.  On macOS 11 check
            // if running on an Apple Silicon GPU to use a memoryless render target.
            if device.supportsFamily(.apple1) {
                texDesc.storageMode = .memoryless
            }
        }
        #else
        texDesc.storageMode = .memoryless
        #endif
        
        _depthTexture = device.makeTexture(descriptor: texDesc)
        
        let colorFormat: MTLPixelFormat = view.colorPixelFormat
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorFormat, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
        
        colorDesc.usage = .shaderRead.union(.renderTarget)
        colorDesc.storageMode = .private;
        _colorTexture = device.makeTexture(descriptor: colorDesc)
    }
    
    func draw(in view: MTKView) {
        /// 绘制描述符
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        // Wait to ensure only AAPLMaxBuffersInFlight are getting processed by any stage in the Metal
        // pipeline (App, Metal, Drivers, GPU, etc).
        
        let _ = self.semaphore.wait(timeout: .distantFuture)

        // Add completion hander which signals _inFlightSemaphore when Metal and the GPU has fully
        // finished processing the commands encoded this frame.  This indicates when the dynamic
        // buffers, written to this frame, will no longer be needed by Metal and the GPU, meaning the
        // buffer contents can be changed without corrupting rendering.

        /// 创建命令缓冲区
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        commandBuffer?.addCompletedHandler({ commandBuffer in
            self.semaphore.signal()
        })
        
        if commandBuffer != nil {
//            encodeTriDegree(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer!)
            encodeSkyDome(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer!)
        }
        
        /// 显示可绘制内容
        if let drawable = view.currentDrawable {
            commandBuffer?.present(drawable)
        }
        
        /// 提交
        commandBuffer?.commit()
    }
    
    func encodeTriDegree(renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        /// 绘制命令编码器
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
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
            
            updateMatrx()
            
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

//            if indexBuffer != nil, indexCount > 0 {
//                renderEncoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer!, indexBufferOffset: 0)
//            } else {
                renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: vertexCount)
//            }
            
//            renderEncoder.updateFence(fence!, after: .fragment)
//            renderEncoder.popDebugGroup()
            
            /// 结束编码
            renderEncoder.endEncoding()
        }
    }
    
    func encodeSkyDome(renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        
//        let renderPassDescriptor = MTLRenderPassDescriptor()
        
//        renderPassDescriptor.colorAttachments[0].texture = _colorTexture
//        renderPassDescriptor.colorAttachments[0].loadAction = .clear;
//        renderPassDescriptor.colorAttachments[0].storeAction = .store;
//        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

//        renderPassDescriptor.depthAttachment = MTLRenderPassDepthAttachmentDescriptor()
//        renderPassDescriptor.depthAttachment.texture = _depthTexture;
//        renderPassDescriptor.depthAttachment.loadAction = .clear;
//        renderPassDescriptor.depthAttachment.storeAction = .dontCare;
//        renderPassDescriptor.depthAttachment.clearDepth = 1.0;

        /// 绘制命令编码器
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        guard let renderEncoder = renderEncoder else {
            return
        }
            
        renderEncoder.setFrontFacing(.counterClockwise)
        
        if let state = depthStencilState {
            renderEncoder.setDepthStencilState(state)
        }
        
        updateMatrx()
        
        if let state = skyDomeState {
            renderEncoder.setRenderPipelineState(state)
            
            let vertexs: [Vertex2D] = [
                Vertex2D(position: [-1, 1], coord: [0, 0]),
                Vertex2D(position: [1, 1], coord: [1, 0]),
                Vertex2D(position: [1, -1], coord: [1, 1]),
                
                Vertex2D(position: [-1, 1], coord: [0, 0]),
                Vertex2D(position: [1, -1], coord: [1, 1]),
                Vertex2D(position: [-1, -1], coord: [1, 0]),
            ]
            
            let vertexBuffer = device.makeBuffer(bytes: vertexs, length: vertexs.count * MemoryLayout<Vertex2D>.size, options: .storageModeShared)
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&contants, length: MemoryLayout<MatrixContants>.size, index: 1)

            renderEncoder.setFragmentTexture(skyTexture, index: 0)

            renderEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: 6)
        }
        
        if let state = skySpheresState {
            renderEncoder.setRenderPipelineState(state)

            renderEncoder.setVertexBuffer(spheresMesh.vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&contants, length: MemoryLayout<MatrixContants>.size, index: 1)

//            renderEncoder.setFragmentTexture(skyTexture, index: 0)

            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: spheresMesh.vertexCount)
        }

        /// 结束编码
        renderEncoder.endEncoding()
    }
}

