//
//  Utility.m
//  MetalDemo
//
//  Created by Peng on 2021/7/20.
//

#import "Utility.h"

#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <Metal/Metal.h>

static CGImageRef CreateCGImageFromFile (NSString* path)
{
    // Get the URL for the pathname passed to the function.
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageRef        myImage = NULL;
    CGImageSourceRef  myImageSource;
    CFDictionaryRef   myOptions = NULL;
    CFStringRef       myKeys[2];
    CFTypeRef         myValues[2];

    // Set up options if you want them. The options here are for
    // caching the image in a decoded form and for using floating-point
    // values if the image format supports them.
    myKeys[0] = kCGImageSourceShouldCache;
    myValues[0] = (CFTypeRef)kCFBooleanFalse;

    myKeys[1] = kCGImageSourceShouldAllowFloat;
    myValues[1] = (CFTypeRef)kCFBooleanTrue;

    // Create the dictionary
    myOptions = CFDictionaryCreate(NULL,
                                   (const void **) myKeys,
                                   (const void **) myValues, 2,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   & kCFTypeDictionaryValueCallBacks);

    // Create an image source from the URL.
    myImageSource = CGImageSourceCreateWithURL((CFURLRef)url, myOptions);
    CFRelease(myOptions);

    // Make sure the image source exists before continuing
    if (myImageSource == NULL)
    {
        fprintf(stderr, "Image source is NULL.");
        return  NULL;
    }

    // Create an image from the first item in the image source.
    myImage = CGImageSourceCreateImageAtIndex(myImageSource, 0, NULL);
    CFRelease(myImageSource);

    // Make sure the image exists before continuing
    if (myImage == NULL)
    {
         fprintf(stderr, "Image not created from image source.");
         return NULL;
    }

    return myImage;
}

static inline void F32ToF16(float F32, __fp16 *F16Ptr) {
    *F16Ptr = F32;
}

uint16_t float16_from_float32(float f) {
    uint16_t f16;
    F32ToF16(f, (__fp16 *)&f16);
    return f16;
}

// Returns a size of the 'inSize' aligned to 'align' as long as align is a power of 2
static NSUInteger alignUp(NSUInteger inSize, NSUInteger align)
{
    // Asset if align is not a power of 2
    assert(((align-1) & align) == 0);

    const NSUInteger alignmentMask = align - 1;

    return ((inSize + alignmentMask) & (~alignmentMask));
}

#pragma mark Texture Load

// --
id<MTLTexture> texture_from_radiance_file(NSString * fileName, id<MTLDevice> device, NSError ** error)
{
    // --------------
    // Validate input

    if (![fileName containsString:@"."])
    {
        if (error != NULL)
        {
            *error = [[NSError alloc] initWithDomain:@"File load failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"No file extension provided."}];
        }
        return nil;
    }

    NSArray * subStrings = [fileName componentsSeparatedByString:@"."];

    if ([subStrings[1] compare:@"hdr"] != NSOrderedSame)
    {
        if (error != NULL)
        {
            *error = [[NSError alloc] initWithDomain:@"File load failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"Only (.hdr) files are supported."}];
        }
        return nil;
    }

    //------------------------
    // Load and Validate Image

    NSString* filePath = [[NSBundle mainBundle] pathForResource:subStrings[0] ofType:subStrings[1]];
    CGImageRef loadedImage = CreateCGImageFromFile(filePath);

    if (loadedImage == NULL)
    {
        if (error != NULL)
        {
            *error = [[NSError alloc] initWithDomain:@"File load failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"Unable to create CGImage."}];
        }

        return nil;
    }

    size_t bpp = CGImageGetBitsPerPixel(loadedImage);

    const size_t kSrcChannelCount = 3;
    const size_t kBitsPerByte = 8;
    const size_t kExpectedBitsPerPixel = sizeof(uint16_t) * kSrcChannelCount * kBitsPerByte;

    if (bpp != kExpectedBitsPerPixel)
    {
        if (error != NULL)
        {
            *error = [[NSError alloc] initWithDomain:@"File load failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Expected %zu bits per pixel, but file returns %zu", kExpectedBitsPerPixel, bpp]}];
        }
        CFRelease(loadedImage);
        return nil;
    }

    //----------------------------
    // Copy image into temp buffer

    size_t width = CGImageGetWidth(loadedImage);
    size_t height = CGImageGetHeight(loadedImage);

    // Make CG image data accessible
    CFDataRef cgImageData = CGDataProviderCopyData(CGImageGetDataProvider(loadedImage));

    // Get a pointer to the data
    const uint16_t * srcData = (const uint16_t * )CFDataGetBytePtr(cgImageData);

    // Metal exposes an RGBA16Float format, but source data is RGB F16, so extra channel of padding added
    const size_t kPixelCount = width * height;
    const size_t kDstChannelCount = 4;
    const size_t kDstSize = kPixelCount * sizeof(uint16_t) * kDstChannelCount;

    uint16_t * dstData = (uint16_t *)malloc(kDstSize);

    for (size_t texIdx = 0; texIdx < kPixelCount; ++texIdx)
    {
        const uint16_t * currSrc = srcData + (texIdx * kSrcChannelCount);
        uint16_t * currDst = dstData + (texIdx * kDstChannelCount);

        currDst[0] = currSrc[0];
        currDst[1] = currSrc[1];
        currDst[2] = currSrc[2];
        currDst[3] = float16_from_float32(1.f);
    }

    //------------------
    // Create MTLTexture

    MTLTextureDescriptor * texDesc = [MTLTextureDescriptor new];

    texDesc.pixelFormat = MTLPixelFormatRGBA16Float;
    texDesc.width = width;
    texDesc.height = height;

    id<MTLTexture> texture = [device newTextureWithDescriptor:texDesc];

    const NSUInteger kBytesPerRow = sizeof(uint16_t) * kDstChannelCount * width;

    MTLRegion region = { {0,0,0}, {width, height, 1} };

    [texture replaceRegion:region mipmapLevel:0 withBytes:dstData bytesPerRow:kBytesPerRow];

    // Remember to clean things up
    free(dstData);
    CFRelease(cgImageData);
    CFRelease(loadedImage);

    return texture;
}

NSString* filePathRead(NSString * fileName, NSError ** error) {
    if (![fileName containsString:@"."]) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File load failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"No file extension provided."}];
        }
        return nil;
    }

    NSArray * subStrings = [fileName componentsSeparatedByString:@"."];

//    if ([subStrings[1] compare:@"hdr"] != NSOrderedSame) {
//        if (error != NULL)
//        {
//            *error = [[NSError alloc] initWithDomain:@"File load failure."
//                                                code:0xdeadbeef
//                                            userInfo:@{NSLocalizedDescriptionKey : @"Only (.hdr) files are supported."}];
//        }
//        return nil;
//    }
    
    NSString* filePath = [[NSBundle mainBundle] pathForResource:subStrings[0] ofType:subStrings[1]];
    return filePath;
}

 Byte * loadImage(NSString * fileName, NSError ** error) {
     NSString * filePath = filePathRead(fileName, error);
     
     UIImage * image = [UIImage imageWithContentsOfFile:filePath];
     
    // 1获取图片的CGImageRef
    CGImageRef spriteImage = image.CGImage;
    
    // 2 读取图片的大小
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    Byte * spriteData = (Byte *) calloc(width * height * 4, sizeof(Byte)); //rgba共4个byte
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4,
                                                       CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    // 3在CGContextRef上绘图
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    return spriteData;
}
