# Metal 入门的那些事

## 图形渲染

[MTLRenderCommandEncoder](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Render-Ctx/Render-Ctx.html#//apple_ref/doc/uid/TP40014221-CH7-SW1)

MTLRenderCommandEncoder命令描述图形渲染管道
![Metal图形绘制管道](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Art/gfx-pipeline_2x.png)

### 创建和使用渲染命令编码器

要创建、初始化和使用单个渲染命令编码器`MTLRenderCommandEncoder`的几个操作：
* 创建MTLRenderPassDescriptor对象，以定义作为该渲染过程的命令缓冲区中图形命令的渲染目标的附件集合。通常，只需创建一次MTLRenderPassDescriptor对象，并在每次应用程序渲染帧时重用它。
* 创建MTLRenderCommandEncoder对象, 通过使用指定的渲染过程描述符调用renderCommandEncoderWithDescriptor:MTLCommandBuffer的方法来创建。
* 创建MTLRenderPipelineState对象，以定义一个或多个绘制调用的图形渲染管道的状态（包括着色器、混合、多重采样和可见性测试）。若要使用此渲染管道状态，调用MTLRenderCommandEncoder的setRenderPipelineState:方法。
* 设置渲染命令编码器要使用的纹理、缓冲区和采样器等指定资源。
* 调用MTLRenderCommandEncoder方法以指定其他固定函数状态，包括深度和模具状态。
* 最后，调用MTLRenderCommandEncoder方法来绘制图形原语。

### 创建渲染管道状态
![sd](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Art/PipelineState_2x.png)

## 三维变换

### 深度模版描述符的配置

从二维世界到三维世界，首先，创建深度模版描述符，并且加入到绘制命令编码器，告诉编码器我们要建立三维坐标。
``` 
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

renderEncoder.setDepthStencilState(state) 

```

此时直接运行模拟器，程序将会报错！😭

> **断点位置：**
`
renderEncoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer!, indexBufferOffset: 0)
`

> **报错信息：**
`
validateDepthStencilState:4140: failed assertion `MTLDepthStencilDescriptor sets depth test but MTLRenderPassDescriptor has a nil depthAttachment texture'
`

MTLRenderPassDescriptor 对象没有深度附属纹理。 按照报错信息为`mtkView.renderPassDescriptor`设置深度附属纹理。
```
let depthFormat: MTLPixelFormat = view.depthStencilPixelFormat
let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthFormat, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
texDesc.usage = .renderTarget
texDesc.storageMode = .memoryless
        
_depthTexture = device.makeTexture(descriptor: texDesc)
```

继续运行模拟器，程序继续报错！😭😭

> **断点位置：**
`
_depthTexture = device.makeTexture(descriptor: texDesc)
`

> **报错信息：**
`
-[MTLDebugDevice newTextureWithDescriptor:]:927: failed assertion `Texture Descriptor Validation
Memoryless texture need to have renderable PixelFormat.
'
`

根据提示查看`view.depthStencilPixelFormat`，发现值为 .invalid 。继续为`mtkView.depthStencilPixelFormat`设置像素样式。
```
func setup() {
    view.depthStencilPixelFormat = .depth32Float
    
    buildPipelineDescriptor()
    
    buildDepthStencilDescriptor()
}
```

**相关解释**：
[链接：Apple](https://developer.apple.com/forums/thread/45486?answerId=180131022#180131022)

>> Are you configuring the depthStencilPixelFormat of your MTKView? It should be set to
.Depth32Float_Stencil8 or similar. If you leave this set to the default (.Invalid), the view won't create a depth texture for you.

**`mtkView.depthStencilPixelFormat` 在模拟器上为默认值 .invalid；真机上为 .depth32Float 。在模拟器上运行需要先为此完成设置。**

设置完`depthStencilPixelFormat`，接着运行项目。然而还是报错！😭😭😭

> **断点位置：**
`
_depthTexture = device.makeTexture(descriptor: texDesc)
`

> **报错信息：**
`
-[MTLDebugRenderCommandEncoder validateFramebufferWithRenderPipelineState:]:1288: failed assertion `Framebuffer With Render Pipeline State Validation
For depth attachment, the render pipeline's pixelFormat (MTLPixelFormatInvalid) does not match the framebuffer's pixelFormat (MTLPixelFormatDepth32Float).
'
`

接着为绘制管道设置深度附属像素样式：
```
func buildPipelineDescriptor() {            
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "Drawable Pipeline";
    pipelineDescriptor.sampleCount = view.sampleCount;
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    
    // 设置深度像素样式
    let depthPixelFormat = view.depthStencilPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat;
    if depthPixelFormat == .stencil8 ||
       depthPixelFormat == .depth32Float_stencil8 ||
       depthPixelFormat == .x32_stencil8 
    {
        /* 格式配置错误会引发报错 */
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    }    
    // ...
}
```

继续运行项目。终于，项目成功跑起来了！😊 ☕️ 三维空间坐标变换的计算了。

***DepthStencilPixelFormat 格式不正确时，程序报错：***
> `
[MTLDebugRenderCommandEncoder validateFramebufferWithRenderPipelineState:]:1228: failed assertion 'For depth attachment, the render pipeline's pixelFormat (MTLPixelFormatDepth32Float) does not match the framebuffer's pixelFormat (MTLPixelFormatDepth32Float_Stencil8).'
`

> `
validateWithDevice:2556: failed assertion `Render Pipeline Descriptor Validation
stencilAttachmentPixelFormat MTLPixelFormatDepth32Float is not stencil renderable.'
`

**总结：三维空间引入深度描述符`MTLDepthStencilDescriptor `，当绘制通行描述符`MTLRenderPassDescriptor`设置了深度描述符时，确保绘制通行描述符与设置的绘制管道描述符`MTLRenderPipelineDescriptor`的深度模版像素样式`depthAttachmentPixelFormat`完成配置并且保持一致。**
```
func setup() {
    _colorPixelFormat = .rgba8Unorm;
    _depthPixelFormat = .depth32Float
    
    /* `view.currentRenderPassDescriptor` 继承 mtkView 的像素样式 */ 
    view.colorPixelFormat = _colorPixelFormat
    view.depthStencilPixelFormat = _depthPixelFormat
    
    buildDepthStencilDescriptor()
    
    buildPipelineDescriptor()
}

func buildPipelineDescriptor() {            
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "Drawable Pipeline";
    
    /* 模拟器下 MTKView `colorPixelFormat `、`depthStencilPixelFormat` 默认值为 .invalid 。不设置的话运行会报错。 */
    // 设置色彩像素样式
    pipelineDescriptor.colorAttachments[0].pixelFormat = _colorPixelFormat;
    
    // 设置深度像素样式
    let depthPixelFormat = _depthPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat;
    if depthPixelFormat == .stencil8 ||
       depthPixelFormat == .depth32Float_stencil8 ||
       depthPixelFormat == .x32_stencil8 
    {
        /* 格式配置错误会引发报错 */
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    }
        
    // 其他配置...
}

func buildDepthTexture(drawableSize: CGSize) {
    let depthFormat: MTLPixelFormat = _depthPixelFormat
    let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthFormat, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
    texDesc.usage = .renderTarget
    texDesc.storageMode = .memoryless
    /* 可用于自创建绘制通行描述符MTLRenderPassDescriptor的深度配置 */
    _depthTexture = device.makeTexture(descriptor: texDesc)
}
```

### 三维空间变换
**在设置3D模型-视图-投影矩阵时，矩阵相乘时的位置应注意莫要写错。**
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
 
