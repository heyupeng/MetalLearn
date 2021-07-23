//
//  Utility.h
//  MetalDemo
//
//  Created by Peng on 2021/7/20.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

static NSUInteger alignUp(NSUInteger inSize, NSUInteger align);

id<MTLTexture> texture_from_radiance_file(NSString * fileName, id<MTLDevice> device, NSError ** error);

Byte * loadImage(NSString * fileName, NSError ** error);
NS_ASSUME_NONNULL_END
