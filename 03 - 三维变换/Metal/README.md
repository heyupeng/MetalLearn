# Metal 入门的那些事

## 三维变换

绘制命令编码器设置深度模版, 即
``` 
renderEncoder.setDepthStencilState(state) 
```

运行报错：
`
validateDepthStencilState:4140: failed assertion `MTLDepthStencilDescriptor sets depth test but MTLRenderPassDescriptor has a nil depthAttachment texture' 
`

断点停留位置：

`
renderEncoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer!, indexBufferOffset: 0)
`


解决方法：[链接：Apple](https://developer.apple.com/forums/thread/45486?answerId=180131022#180131022)

> Are you configuring the depthStencilPixelFormat of your MTKView? It should be set to
.Depth32Float_Stencil8 or similar. If you leave this set to the default (.Invalid), the view won't create a depth texture for you.

```
func setupDescriptor() {
    /*
    mtkView.depthStencilPixelFormat 在模拟器上为默认值(.invalid)，真机上为 .depth32Float 。
    稳妥起见，在建立描述符前设置 mtkView.depthStencilPixelFormat，保持参数一致。
    */
    view.depthStencilPixelFormat = .depth32Float_stencil8

    buildPipelineDescriptor()

    buildDepthStencilDescriptor()
}

func buildPipelineDescriptor() {            
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "Drawable Pipeline";
    pipelineDescriptor.sampleCount = view.sampleCount;
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    // pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    
    // ...
}

```

`depthStencilPixelFormat`不一致时，程序会报错。

[MTLDebugRenderCommandEncoder validateFramebufferWithRenderPipelineState:]:1228: failed assertion `For depth attachment, the render pipeline's pixelFormat (MTLPixelFormatDepth32Float) does not match the framebuffer's pixelFormat (MTLPixelFormatDepth32Float_Stencil8).'


在设置3D模型-视图-投影矩阵时，矩阵相乘时的位置应注意莫要写错。
```
    var modelMatrix = GLKMatrix4Identity
    modelMatrix = GLKMatrix4RotateX(modelMatrix, .pi * 0.25 * -1)
    modelMatrix = GLKMatrix4RotateY(modelMatrix, .pi * 0.25 * -1)
    // <!-- 代码上如此先旋转X轴，再Y轴。在模型矩阵相乘上先旋转Y轴，再旋转X轴 -->
    
     /// 合并模型 - 视图 - 投影
    var matrix =  GLKMatrix4Identity
    matrix = GLKMatrix4Multiply(viewMatrix, modelMatrix)
    matrix = GLKMatrix4Multiply(projectionMatrix, matrix)
```
 
