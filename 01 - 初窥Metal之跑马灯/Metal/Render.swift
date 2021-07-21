//
//  Render.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

import UIKit
import MetalKit

class Render: NSObject, MTKViewDelegate {
    var view: MTKView!
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    
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
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("Tips: The drawable size of mtkView will change")
    }
    
    func radomColor() -> MTLClearColor {
        let r = arc4random_uniform(255)
        let g = arc4random_uniform(255)
        let b = arc4random_uniform(255)
        
        let rr = Double(r) / 255.0
        let gg = Double(g) / 255.0
        let bb = Double(b) / 255.0
        
        return MTLClearColor(red: rr, green: gg, blue: bb, alpha: 1)
    }
    
    func draw(in view: MTKView) {
        view.clearColor = radomColor()
        
        /// 绘制描述符
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        ///
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        /// 绘制命令编码器
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        if let renderCommandEncoder = renderCommandEncoder {
            // To do.
            // ...
            
            /// 结束编码
            renderCommandEncoder.endEncoding()
            /// 显示可绘制内容
            if let drawable = view.currentDrawable {
                commandBuffer?.present(drawable)
            }
        }
        
        /// 提交
        commandBuffer?.commit()
    }
    
}
