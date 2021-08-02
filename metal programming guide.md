[Metal Programming Guide]: https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Render-Ctx/Render-Ctx.html#//apple_ref/doc/uid/TP40014221-CH7-SW1

[MetalFeatureSetTables]: https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/MetalFeatureSetTables/MetalFeatureSetTables.html#//apple_ref/doc/uid/TP40014221-CH13-SW1

<!-- Class Link -->
[MTLRenderCommandEncoder]: https://developer.apple.com/documentation/metal/mtlrendercommandencoder

[MTLParallerRenderCommandEncoder]: https://developer.apple.com/documentation/metal/mtlparallelrendercommandencoder

[MTLRenderPassDescriptor]: https://developer.apple.com/documentation/metal/mtlrenderpassdescriptor

[MTLRenderPipelineState]: https://developer.apple.com/documentation/metal/mtlrenderpipelinestate

[MTLRenderCommandEncoder]: https://developer.apple.com/documentation/metal/mtlrendercommandencoder

# Metal指南

[Metal Programming Guide][]

## 图形渲染: 渲染命令编码器

本章介绍如何创建和使用[MTLRenderCommandEncoder]和[MTLParallerRenderCommandEncoder]对象，这些对象用于将图形渲染命令编码到命令缓冲区。MTLRenderCommandEncoder命令描述图形渲染管道，如图5-1所示。

![Metal图形绘制管道](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Art/gfx-pipeline_2x.png)
    <!-- 如图5-1 图形渲染管道 -->
MTLRenderCommandEncoder对象表示单个渲染命令编码器。MTLParallelRenderCommandEncoder对象允许将单个渲染过程分解为多个单独的MTLRenderCommandEncoder对象，每个对象都可以分配给不同的线程。然后将来自不同渲染命令编码器的命令链接在一起，并按照一致、可预测的顺序执行，如渲染过程的多线程中所述。

## 创建和使用渲染命令编码器

创建、初始化和使用单个渲染命令编码器`MTLRenderCommandEncoder`的几个操作：
* 创建[MTLRenderPassDescriptor]对象，以定义作为该渲染过程的命令缓冲区中图形命令的渲染目标的附件集合。通常，只需创建一次MTLRenderPassDescriptor对象，并在每次应用程序渲染帧时重用它。参见[创建渲染管道状态](#创建渲染过程描述符)
* 创建MTLRenderCommandEncoder对象, 通过使用指定的渲染过程描述符调用renderCommandEncoderWithDescriptor:MTLCommandBuffer的方法来创建。
* 创建[MTLRenderPipelineState]对象，以定义一个或多个绘制调用的图形渲染管道的状态（包括着色器、混合、多重采样和可见性测试）。若要使用此渲染管道状态，调用MTLRenderCommandEncoder的setRenderPipelineState:方法。参见[创建渲染管道状态](#创建渲染管道状态)
* 设置渲染命令编码器要使用的纹理、缓冲区和采样器等指定资源。
* 调用MTLRenderCommandEncoder方法以指定其他固定函数状态，包括深度和模具状态。
* 最后，调用MTLRenderCommandEncoder方法来绘制图形原语。

### 创建渲染过程描述符
[MTLRenderPassDescriptor]对象表示编码呈现命令的目标，该目标是附件的集合。渲染过程描述符的属性可以包括最多四个用于颜色像素数据的附件、一个用于深度像素数据的附件和一个用于模具像素数据的附件的阵列。renderPassDescriptor便捷方法创建一个MTLRenderPassDescriptor对象，该对象具有默认附件状态下的颜色、深度和模具附件属性。visibilityResultBuffer属性指定一个缓冲区，设备可以在其中更新以指示是否有任何样本通过深度和模具测试。有关详细信息，请参阅固定功能状态操作。

每个单独的附件（包括将写入的纹理）都由附件描述符表示。对于附件描述符，必须适当选择关联纹理的像素格式以存储颜色、深度或模具数据。对于颜色附件描述符MTLRenderPassColorAttachmentDescriptor，请使用颜色可渲染像素格式。对于深度附件描述符MTLRenderPassdepthatAttachmentDescriptor，请使用深度可渲染像素格式，例如MTLPixelFormatDepth32Float。对于模具附件描述符MTLRenderPassStencilAttachmentDescriptor，请使用模具可渲染像素格式，例如MTLPixelFormatStencil8。

纹理在设备上每像素实际使用的内存量并不总是与金属框架代码中纹理像素格式的大小相匹配，因为设备为对齐或其他目的添加了填充。有关每个像素格式实际使用的内存量以及附件大小和数量的限制，参见[Metal特征表][MetalFeatureSetTables]一章。

### 加载和存储操作(Load and Store Actions)

附件描述符的loadAction和storeAction属性指定在渲染过程的开始或结束时执行的操作(对于MTLParallelRenderCommandEncoder，加载和存储操作发生在整个命令的边界处，而不是每个MTLRenderCommandEncoder对象。有关详细信息，请参见渲染过程的多线程。）

可能的loadAction值包括：
* MTLLoadActionClear，它将相同的值写入指定附件描述符中的每个像素。有关此操作的更多详细信息，请参见指定清除加载操作。
* MTLLoadActionLoad，它保留纹理的现有内容。
* MTLLoadActionDontCare，它允许附件中的每个像素在渲染过程开始时采用任何值。

如果应用程序将呈现给定帧附件的所有像素，请使用默认加载操作MTLLoadActionDontCare。MTLLoadActionDontCare操作允许GPU避免加载纹理的现有内容，从而确保最佳性能。否则，您可以使用MTLLoadActionClear操作清除附件以前的内容，或使用MTLLoadActionLoad操作保留这些内容。MTLLoadActionClear操作还可以避免加载现有纹理内容，但它会产生用纯色填充目标的成本。

可能的storeAction值包括：
* MTLStoreActionStore，它将渲染过程的最终结果保存到附件中。
* MTLStoreActionMultisampleResolve将来自渲染目标的多采样数据解析为单个采样值，将其存储在附件属性resolveTexture指定的纹理中，并保留附件的内容未定义。有关详细信息，请参见示例：为多采样渲染创建渲染过程描述符。
* MTLStoreActionDontCare，它在渲染过程完成后使附件处于未定义状态。这可能会提高性能，因为它使实现能够避免保留渲染结果所需的任何工作。

对于颜色附件，MTLStoreActionStore操作是默认的存储操作，因为应用程序几乎总是在渲染过程结束时保留附件中的最终颜色值。对于深度和模具附件，MTLStoreActionDontCare是默认的存储操作，因为渲染过程完成后通常不需要保留这些附件。

### 指定清除加载操作

如果附件描述符的loadAction属性设置为MTLLoadActionClear，则在渲染过程开始时，会将清除值写入指定附件描述符中的每个像素。清除值属性取决于附件的类型。

* 对于MTLRenderPassColorAttachmentDescriptor，clearColor包含一个MTLClearColor值，该值由四个双精度浮点RGBA组件组成，用于清除颜色附件。MTLClearColorMake函数从红色、绿色、蓝色和alpha组件创建清晰的颜色值。默认的透明颜色为（0.0、0.0、0.0、1.0）或不透明黑色。

* 对于MTLRenderPassdephattachmentDescriptor，clearDepth包含一个范围为[0.0,1.0]的双精度浮点清除值，用于清除深度附件。默认值为1.0。

* 对于MTLRenderPassStencilAttachmentDescriptor，ClearTencil包含一个用于清除模具附件的32位无符号整数。默认值为0。

### 示例：使用加载和存储操作创建渲染过程描述符
清单5-1创建了一个带有颜色和深度附件的简单渲染过程描述符。首先，创建两个纹理对象，一个具有颜色可渲染像素格式，另一个具有深度像素格式。接下来，MTLRenderPassDescriptor的renderPassDescriptor便利方法将创建一个默认的渲染过程描述符。然后通过MTLRenderPassDescriptor的属性访问颜色和深度附件。纹理和动作在colorAttachments[0]中设置，它表示第一个颜色附件（在数组中的索引0处）和深度附件。

```
// 清单5-1 创建带有颜色和深度附件的渲染过程描述符
MTLTextureDescriptor *colorTexDesc = [MTLTextureDescriptor
           texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
           width:IMAGE_WIDTH height:IMAGE_HEIGHT mipmapped:NO];

id <MTLTexture> colorTex = [device newTextureWithDescriptor:colorTexDesc];

MTLTextureDescriptor *depthTexDesc = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
           width:IMAGE_WIDTH height:IMAGE_HEIGHT mipmapped:NO];

id <MTLTexture> depthTex = [device newTextureWithDescriptor:depthTexDesc];

MTLRenderPassDescriptor *renderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];

renderPassDesc.colorAttachments[0].texture = colorTex;
renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0,1.0,0.0,1.0);

renderPassDesc.depthAttachment.texture = depthTex;
renderPassDesc.depthAttachment.loadAction = MTLLoadActionClear;
renderPassDesc.depthAttachment.storeAction = MTLStoreActionStore;
renderPassDesc.depthAttachment.clearDepth = 1.0;

```

### 示例：为多采样渲染创建渲染过程描述符
若要使用MTLStoreActionMultisampleResolve操作，必须将纹理属性设置为多采样类型纹理，并且resolveTexture属性将包含多采样解析操作的结果(如果纹理不支持多重采样，则多重采样解析操作的结果未定义。）resolveLevel、resolveSlice和resolveDepthPlane属性也可用于多重采样解析操作，以分别指定多重采样纹理的mipmap级别、立方体切片和深度平面。在大多数情况下，resolveLevel、resolveSlice和resolveDepthPlane的默认值可用。在清单5-2中，首先创建一个附件，然后将其loadAction、storeAction、texture和resolveTexture属性设置为支持多样本解析。

```
// 清单5-2 使用Multisample Resolve设置附件的属性

MTLTextureDescriptor *colorTexDesc = [MTLTextureDescriptor 
    texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
    width:IMAGE_WIDTH height:IMAGE_HEIGHT mipmapped:NO];

id <MTLTexture> colorTex = [device newTextureWithDescriptor:colorTexDesc];

MTLTextureDescriptor *msaaTexDesc = [MTLTextureDescriptor
           texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
           width:IMAGE_WIDTH height:IMAGE_HEIGHT mipmapped:NO];

msaaTexDesc.textureType = MTLTextureType2DMultisample;
msaaTexDesc.sampleCount = sampleCount;  //  must be > 1

id <MTLTexture> msaaTex = [device newTextureWithDescriptor:msaaTexDesc];

MTLRenderPassDescriptor *renderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];
renderPassDesc.colorAttachments[0].texture = msaaTex;
renderPassDesc.colorAttachments[0].resolveTexture = colorTex;
renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0,1.0,0.0,1.0);

```

### 使用渲染过程描述符创建渲染命令编码器
创建渲染过程描述符并指定其属性后，使用MTLCommandBuffer对象的renderCommandEncoderWithDescriptor:方法创建渲染命令编码器，如清单5-3所示。
```
/// 清单5-3 使用渲染过程描述符创建渲染命令编码器
id <MTLRenderCommandEncoder> renderCE = [commandBuffer 
    renderCommandEncoderWithDescriptor:renderPassDesc];
```

## 创建渲染管道状态

若要使用MTLRenderCommandEncoder对象对渲染命令进行编码，必须首先指定MTLRenderPipelineState对象以定义任何绘制调用的图形状态。渲染管道状态对象是一个长寿命的持久对象，可以在渲染命令编码器外部创建、提前缓存，并跨多个渲染命令编码器重用。在描述同一组图形状态时，重用先前创建的渲染管道状态对象可以避免昂贵的操作，这些操作会重新计算指定状态并将其转换为GPU命令。

渲染管道状态是不可变的对象。要创建渲染管道状态，首先创建并配置一个可变的MTLRenderPipelineDescriptor对象，该对象描述渲染管道状态的属性。然后，使用描述符创建MTLRenderPipelineState对象。

#### 创建和配置渲染管道描述符
要创建渲染管道状态，请首先创建一个MTLRenderPipelineDescriptor对象，该对象具有描述要在渲染过程中使用的图形渲染管道状态的属性，如图5-2所示。新MTLRenderPipelineDescriptor对象的colorAttachments属性包含一个MTLRenderPipelineColorAttachmentDescriptor对象数组，每个描述符表示一个颜色附件状态，指定该附件的混合操作和系数，如在渲染管道附件描述符中配置混合中所述。附件描述符还指定附件的像素格式，该格式必须与渲染管道描述符纹理的像素格式与相应的附件索引相匹配，否则将发生错误。

图5-2从描述符创建渲染管道状态

![渲染管道状态](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Art/PipelineState_2x.png)

除了配置颜色附件外，还要为MTLRenderPipelineDescriptor对象设置以下属性：

* 设置depthAttachmentPixelFormat属性以匹配MTLRenderPassDescriptor中depthAttachment纹理的像素格式。

* 设置stencilAttachmentPixelFormat属性以匹配MTLRenderPassDescriptor中stencilAttachment纹理的像素格式。
要在渲染管道状态下指定顶点或片段着色器，请分别设置vertexFunction或fragmentFunction属性。将fragmentFunction设置为nil将禁用将像素光栅化为指定颜色附件的功能，该附件通常用于仅深度渲染或将数据从顶点着色器输出到缓冲区对象。

* 如果顶点着色器具有逐顶点输入属性的参数，请设置vertexDescriptor属性以描述该参数中顶点数据的组织，如“数据组织的顶点描述符”中所述。

* 对于大多数典型的渲染任务，“光栅化启用”属性的默认值为“是”就足够了。若要仅使用图形管道的顶点阶段（例如，收集在顶点着色器中变换的数据），请将此属性设置为“否”。

* 如果附件支持多重采样（即，附件是MTLTextureType2DMultisample类型纹理），则可以为每个像素创建多个采样。要确定片段如何组合以提供像素覆盖，请使用以下MTLRenderPipelineDescriptor属性。
- - sampleCount属性确定每个像素的采样数。创建MTLRenderCommandEncoder时，所有附件的纹理的sampleCount必须与此sampleCount属性匹配。如果附件不支持多重采样，则sampleCount为1，这也是默认值。
- - 如果alphaToCoverageEnabled设置为YES，则读取colorAttachments[0]的alpha通道片段输出，并用于确定覆盖率掩码。
- - 如果alphaToOneEnabled设置为YES，则colorAttachments[0]的alpha通道片段值强制为1.0，这是最大的可表示值(其他附件不受影响。）

### 从描述符创建渲染管道状态

创建渲染管道描述符并指定其属性后，使用它创建MTLRenderPipelineState对象。由于创建渲染管道状态可能需要对图形状态进行昂贵的评估，并可能需要编译指定的图形着色器，因此您可以使用阻塞或异步方法，以最适合应用程序设计的方式安排此类工作。

* 要同步创建渲染管道状态对象，请调用MTLDevice对象的newRenderPipelineStateWithDescriptor:error:或newRenderPipelineStateWithDescriptor:options:reflection:error:方法。当Metal计算描述符的图形状态信息并编译着色器代码以创建管道状态对象时，这些方法会阻止当前线程。

* 要异步创建渲染管道状态对象，请调用MTLDevice对象的newRenderPipelineStateWithDescriptor:completionHandler:或newRenderPipelineStateWithDescriptor:options:completionHandler:方法。这些方法立即返回，并异步计算描述符的图形状态信息，编译着色器代码以创建管道状态对象，然后调用完成处理程序以提供新的MTLRenderPipelineState对象。

创建MTLRenderPipelineState对象时，还可以选择创建反映管道着色器函数及其参数细节的反射数据。newRenderPipelineStateWithDescriptor:options:reflection:error:和newRenderPipelineStateWithDescriptor:options:completionHandler:方法提供此数据。如果不使用反射数据，请避免获取反射数据。有关如何分析反射数据的更多信息，请参阅在运行时确定函数详细信息。

创建MTLRenderPipelineState对象后，调用MTLRenderCommandEncoder的setRenderPipelineState:方法将渲染管道状态与用于渲染的命令编码器关联。

清单5-5演示了一个pipeline的渲染管道状态对象的创建。
```
// Listing 5-5  Creating a Simple Pipeline State

MTLRenderPipelineDescriptor *renderPipelineDesc =
                             [[MTLRenderPipelineDescriptor alloc] init];

renderPipelineDesc.vertexFunction = vertFunc;
renderPipelineDesc.fragmentFunction = fragFunc;
renderPipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;

// Create MTLRenderPipelineState from MTLRenderPipelineDescriptor
NSError *errors = nil;

id <MTLRenderPipelineState> pipeline = [device
         newRenderPipelineStateWithDescriptor:renderPipelineDesc error:&errors];

assert(pipeline && !errors);

// Set the pipeline state for MTLRenderCommandEncoder
[renderCE setRenderPipelineState:pipeline];
```

变量`vertFunc`和`fragFunc`是着色器函数，指定为名为renderPipelineDesc的渲染管道状态描述符的属性。调用`MTLDevice `对象的`newRenderPipelineStateWithDescriptor:error:method`同步使用管道状态描述符创建渲染管道状态对象。调用`MTLRenderCommandEncoder `的`setRenderPipelineState:`方法指定要与render命令编码器一起使用的`MTLRenderPipelineState `对象。

==注意：== 由于`MTLRenderPipelineState`对象的创建成本很高，因此无论何时需要使用相同的图形状态，都应该重用它。

<!-- 在渲染管道附件描述符中配置混合 -->
[MTLRenderPipelineColorAttachmentDescriptor]: https://developer.apple.com/documentation/metal/mtlrenderpipelinecolorattachmentdescriptor

### 混合配置
混合使用高度可配置的混合操作，将片段函数（源）返回的输出与附件（目标）中的像素值混合。混合操作确定源值和目标值如何与混合因子组合。
要为颜色附件配置混合，请设置以下[MTLRenderPipelineColorAttachmentDescriptor]属性：

* 要启用混合，请将blendingEnabled设置为YES。默认情况下，混合处于禁用状态。

* writeMask标识要混合的颜色通道。默认值MTLColorWriteMaskAll允许混合所有颜色通道。
* rgbBlendOperation和alphaBlendOperation分别为RGB和Alpha片段数据指定混合操作和MTLBlendOperation值。这两个属性的默认值均为MTLBlendOperationAdd。

* sourceRGBBlendFactor、sourceAlphaBlendFactor、destinationRGBBlendFactor和destinationAlphaBlendFactor指定源和目标混合因子。

### 了解混合因素和操作
四个混合因子表示恒定的混合颜色值：MTLBlendFactorLendColor、MTLBlendFactorNeminusBlendColor、MTLBlendFactorLendAlpha和MTLBlendFactorNeminusBlendAlpha。调用`MTLRenderCommandEncoder的setBlendColorRed:green:blue:alpha:method `来指定与这些混合因子一起使用的恒定颜色和alpha值，如固定函数状态操作中所述。
一些混合操作通过将源值乘以源MTLBlendFactor值（缩写为SBF）、将目标值乘以目标混合因子（DBF）以及使用MTLBlendOperation值指示的算术组合结果来组合片段值(如果混合操作为MTLBlendOperationMin或MTLBlendOperationMax，则SBF和DBF混合因子将被忽略。）例如，rgbBlendOperation和alphaBlendOperation属性的MTLBlendOperationAdd为RGB和Alpha值定义了以下相加混合操作：

* RGB = (Source.rgb * `sourceRGBBlendFactor`) + (Dest.rgb * `destinationRGBBlendFactor `)
* Alpha = (Source.a * `sourceAlphaBlendFactor `) + (Dest.a *  `destinationAlphaBlendFactor`)

在默认混合行为中，源完全覆盖目标。此行为相当于将sourceRGBBlendFactor和`sourceAlphaBlendFactor`设置为`MTLBlendFactorOne`，将`destinationRGBBlendFactor`和`destinationAlphaBlendFactor`设置为`MTLBlendFactorZero`。该行为在数学上表示为：
* RGB = (Source.rgb * 1.0) + (Dest.rgb * 0.0)
* A = (Source.a * 1.0) + (Dest.a * 0.0)

另一种常用的混合操作（源alpha定义了目标颜色的剩余量）可以用数学表示为：
* RGB = (Source.rgb * 1.0) + (Dest.rgb * (1 - Source.a))
* A = (Source.a * 1.0) + (Dest.a * (1 - Source.a))

### 使用自定义混合配置
清单5-6显示了自定义混合配置的代码，使用混合操作MTLBlendOperationAdd、源混合因子MTLBlendFactoryOne和目标混合因子MTLBlendFactoryNameNussourceAlpha。colorAttachments[0]是一个MTLRenderPipelineColorAttachmentDescriptor对象，其属性指定混合配置。

```
// Listing 5-6  Specifying a Custom Blending Configuration

MTLRenderPipelineDescriptor *renderPipelineDesc = 
                             [[MTLRenderPipelineDescriptor alloc] init];
renderPipelineDesc.colorAttachments[0].blendingEnabled = YES; 
renderPipelineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
renderPipelineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
renderPipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
renderPipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
renderPipelineDesc.colorAttachments[0].destinationRGBBlendFactor = 
       MTLBlendFactorOneMinusSourceAlpha;
renderPipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = 
       MTLBlendFactorOneMinusSourceAlpha;

NSError *errors = nil;
id <MTLRenderPipelineState> pipeline = [device 
         newRenderPipelineStateWithDescriptor:renderPipelineDesc error:&errors];
```

### 为渲染命令编码器指定资源
本节讨论的MTLRenderCommandEncoder方法指定用作顶点和片段着色器函数参数的资源，这些函数由`MTLRenderPipelineState`对象中的`vertexFunction`和`fragmentFunction`属性指定。这些方法将着色器资源（缓冲区、纹理和采样器）分配给渲染命令编码器中相应的参数表索引（`atIndex `），如图5-3所示。

<!-- Figure 5-3  渲染命令编码器的参数表 -->
![Figure 5-3](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Art/ArgTable-render_2x.png)


以下`setVertex*`方法将一个或多个资源分配给顶点着色器函数的相应参数。

	• setVertexBuffer:offset:atIndex:
	• setVertexBuffers:offsets:withRange:
	• setVertexTexture:atIndex:
	• setVertexTextures:withRange:
	• setVertexSamplerState:atIndex:
	• setVertexSamplerState:lodMinClamp:lodMaxClamp:atIndex:
	• setVertexSamplerStates:withRange:
	• setVertexSamplerStates:lodMinClamps:lodMaxClamps:withRange:

以下类似地`setFragment*`方法将一个或多个资源分配给片段着色器函数的相应参数。
    
	• setFragmentBuffer:offset:atIndex:
	• setFragmentBuffers:offsets:withRange:
	• setFragmentTexture:atIndex:
	• setFragmentTextures:withRange:
	• setFragmentSamplerState:atIndex:
	• setFragmentSamplerState:lodMinClamp:lodMaxClamp:atIndex:
	• setFragmentSamplerStates:withRange:
	• setFragmentSamplerStates:lodMinClamps:lodMaxClamps:withRange

缓冲区参数表中最多有31个条目，纹理参数表中最多有31个条目，采样器状态参数表中最多有16个条目。

在Metal着色语言源代码中指定资源位置的属性限定符必须与金属框架方法中的参数表索引匹配。在清单5-7中，为顶点着色器定义了两个索引分别为0和1的缓冲区（posBuf, texCoordBuf）。
```
// Listing 5-7  Metal Framework: Specifying Resources for a Vertex Function
[renderEnc setVertexBuffer:posBuf offset:0 atIndex:0];
[renderEnc setVertexBuffer:texCoordBuf offset:0 atIndex:1];
```

在清单5-8中，函数签名具有与属性限定符`buffer(0)`和`buffer(1)`对应的参数。
```
// Listing 5-8 Metal Shader Language: 顶点函数参数与框架参数表索引匹配
vertex VertexOutput metal_vert(float4 *posData [[ buffer(0) ]],
                               float2 *texCoordData [[ buffer(1) ]]
```

类似地，在清单5-9中，为片段着色器定义了索引为0的缓冲区、纹理和采样器（分别为fragmentColorBuf、shadeTex和sampler）。
```
// Metal Framework: Specifying Resources for a Fragment Function
[renderEnc setFragmentBuffer:fragmentColorBuf offset:0 atIndex:0];
[renderEnc setFragmentTexture:shadeTex atIndex:0];
[renderEnc setFragmentSamplerState:sampler atIndex:0];
```

在清单5-10中，函数签名分别具有属性限定符`buffer(0)`、`texture(0)`和`sampler(0)`的相应参数。
```
// Metal Shader Language: 片段函数参数与框架参数表索引匹配
fragment float4 metal_frag(VertexOutput in [[stage_in]],
                           float4 *fragColorData [[ buffer(0) ]],
                           texture2d<float> shadeTexValues [[ texture(0) ]],
                           sampler samplerValues [[ sampler(0) ]] )

```

### 数据组织的顶点描述符

在Metal框架代码中，每个管道状态可以有一个`MTLVertexDescriptor`，用于描述输入顶点着色器函数的数据组织，并在着色语言和框架代码之间共享资源位置信息。

在Metal着色语言代码中，逐顶点输入（例如整型或浮点值的标量或向量）可以组织在一个结构中，该结构可以在一个参数中传递，该参数使用`[[stage_In]]`属性限定符声明，如清单5-11中顶点函数`vertexMath `的`VertexInput`结构所示。逐顶点输入结构的每个字段都有`[[attribute(index)]`限定符，用于指定顶点属性参数表中的索引。

```
// Listing 5-11  Metal Shading Language: 具有属性索引的顶点函数输入

struct VertexInput {
    float2    position [[ attribute(0) ]];
    float4    color    [[ attribute(1) ]];
    float2    uv1      [[ attribute(2) ]];
    float2    uv2      [[ attribute(3) ]];
};

struct VertexOutput {
    float4 pos [[ position ]];
    float4 color;
};

vertex VertexOutput vertexMath(VertexInput in [[ stage_in ]])
{
  VertexOutput out;
  out.pos = float4(in.position.x, in.position.y, 0.0, 1.0);

  float sum1 = in.uv1.x + in.uv2.x;
  float sum2 = in.uv1.y + in.uv2.y;
  out.color = in.color + float4(sum1, sum2, 0.0f, 0.0f);
  return out;
}

```

### 执行固定功能渲染命令编码器操作
使用以下[MTLRenderCommandEncoder]方法设置固定的函数图形状态值：

`setViewport：`
以屏幕坐标指定区域，该区域是虚拟3D世界投影的目标。视口是3D的，因此它包含深度值；有关详细信息，请参见使用视口和像素坐标系。

`setTriangleFillMode：`
确定是使用直线（MTLTriangleFillModeLines）还是填充三角形（MTLTriangleFillModeFill）栅格化三角形和三角形条带基本体。默认值为MTLTriangleFillModeFill。

`setCullMode:`和`setFrontFacingWinding:`
一起用于确定是否应用剔除以及如何应用剔除。可以在某些几何模型上使用消隐来删除隐藏曲面，例如使用填充三角形渲染的可定向球体(如果曲面的基本体始终按顺时针或逆时针顺序绘制，则曲面是可定向的。）

`setFrontFacingWinding`的值：指示前向基本体的顶点是按顺时针（MTLwinding顺时针）还是逆时针（MTLwinding逆时针）顺序绘制的。默认值为MTLwinding顺时针。

`setCullMode `的值：确定是否执行消隐（如果禁用消隐，则为MTLCullModeNone）或要消隐的原语类型（MTLCullModeFront或MTLCullModeBack）。

使用以下[MTLRenderCommandEncoder]方法对固定功能状态更改命令进行编码：

	• setScissorRect:
	• setDepthStencilState:
	• setStencilReferenceValue:
	• setDepthBias:slopeScale:clamp: 
	• setVisibilityResultMode:offset: 
	• setBlendColorRed:green:blue:alpha: 

`setScissorRect:`指定二维剪切矩形。位于指定剪切矩形之外的碎片将被丢弃。

`setDepthStencilState:`设置深度和模具测试状态，如深度和模具状态中所述。

`SetSetTencilReferenceValue:`指定模具参考值。

`setDepthBias:slopeScale:clamp:`指定用于将阴影贴图与片段着色器输出的深度值进行比较的调整。

`setVisibilityResultMode:offset:`确定是否监视任何样本是否通过深度和模具测试。如果设置为`MTLVisibilityResultModeBoolean`，则如果任何采样通过深度和模具测试，则会将非零值写入由`MTLRenderPassDescriptor`的`visibilityResultBuffer`属性指定的缓冲区，如创建渲染过程描述符中所述。
可以使用此模式执行遮挡测试。如果绘制边界框且没有采样通过，则可能会得出结论，即该边界框内的任何对象都被遮挡，因此不需要渲染。

`setBlendColorRed:green:blue:alpha:`指定恒定的混合颜色和alpha值，如在渲染管道附件描述符中配置混合中所述。

