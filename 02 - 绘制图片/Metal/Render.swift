//
//  Render.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

import UIKit
import MetalKit

class Render: NSObject, MTKViewDelegate {
    struct Vertex {
        var position: vector_float2
        var coord: vector_float2
    }
    
    var view: MTKView!
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    var pipelineState : MTLRenderPipelineState?
    
    var vertexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    
    var texture: MTLTexture?
    
    init?(mtkView: MTKView) {
        self.view = mtkView
        
        /// 创建 Metal device。
        if let defaultDevice = MTLCreateSystemDefaultDevice() {
            device = defaultDevice
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
        
        buildVertex()
        
        buildPipelineDescriptor()
        
        loadTexture()
    }
    
    func buildVertex() {
//                            Vertex     |  Texture    |
//                          Positions    | Coordinates |
        let vertexs: [Vertex] = [
            Vertex(position: [ 1.0, -1.0], coord: [1.0, 1.0]),
            Vertex(position: [-1.0, -1.0], coord: [0.0, 1.0]),
            Vertex(position: [-1.0,  1.0], coord: [0.0, 0.0]),
            Vertex(position: [ 1.0, -1.0], coord: [1.0, 1.0]),
            Vertex(position: [-1.0,  1.0], coord: [0.0, 0.0]),
            Vertex(position: [ 1.0,  1.0], coord: [1.0, 0.0])
        ]
        
        let vertexLength = vertexs.count * MemoryLayout<Vertex>.size
        let vertexCount = vertexs.count
        
        let vertexBuffer = device.makeBuffer(bytes: vertexs, length: vertexLength, options: MTLResourceOptions.storageModeShared)
        vertexBuffer?.label = "Vertex"
        
        self.vertexBuffer = vertexBuffer
        self.vertexCount = vertexCount
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
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
        
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Unable to compile render pipeline state")
        }
    }
    
    func loadTexture() {
//        let name = "checkerboard"
//        do {
//            texture = try Self.buildTexture(assetsName: name, device)
//        } catch {
//            print("Unable to load texture in assets named \(name)")
//        }
        
        let fileName = "Image0.jpg"
        do {
            texture = try Self.buildTexture(fileName: fileName, device)
        } catch {
            print("No texture!")
        }
    }
    
    // MARK: class func
    
    /// Read Texture from Asset
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
    
    /// Read Texture from main bundle
    class func buildTexture(fileName: String, _ device: MTLDevice) throws -> MTLTexture {
        let cmps = fileName.split(separator: ".")
        if cmps.count < 2 {
            let desc = "No file extension and could not load image \(fileName)"
            let info = [NSLocalizedDescriptionKey: desc]
            let err = NSError(domain: "com.loadTexture", code: 1, userInfo: info)
            throw err
        }
        
        let name = String(describing: cmps.first!)
        let ext = String(describing: cmps.last!)
        let url = Bundle.main.url(forResource: name, withExtension: ext)
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
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("Tips: The drawable size of mtkView will change")
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
            
            if let pipelineState = self.pipelineState {
                renderEncoder.setRenderPipelineState(pipelineState)
            }
            
            var scale: vector_float2 = vector_float2(1.0, 1.0)
            let drawableRate = view.drawableSize.width / view.drawableSize.height
            let textureRate = CGFloat(texture!.width) / CGFloat(texture!.height)
            if drawableRate > textureRate {
                scale.x = Float(textureRate / drawableRate)
            } else {
                scale.y = Float(drawableRate / textureRate)
            }
            
            renderEncoder.setVertexBuffer(vertexBuffer!, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&scale, length: MemoryLayout<vector_float2>.size, index: 1)
            
            renderEncoder.setFragmentTexture(texture, index: 0)

            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
            
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
