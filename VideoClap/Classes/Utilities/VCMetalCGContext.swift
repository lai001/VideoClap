//
//  VCMetalCGContext.swift
//  VideoClap
//
//  Created by lai001 on 2021/4/4.
//

import Foundation
import CoreGraphics
import Metal
import MetalKit

@available(iOS 12.0, *)
public class VCMetalCGContext: NSObject {
    
    public let cgContext: CGContext
    
    public let texture: MTLTexture
    
    public init(width: Int, height: Int) throws {
        let domain = "VCMetalCGContext"
        #if targetEnvironment(simulator)
        throw NSError(domain: domain, code: 1, userInfo: [NSLocalizedFailureReasonErrorKey:"Not supported in simulator"])
        #endif
        guard let device = MetalDevice.share.device else {
            throw NSError(domain: domain, code: 2, userInfo: [NSLocalizedFailureReasonErrorKey:"Metal is not available"])
        }
        let pixelRowAlignment = device.minimumTextureBufferAlignment(for: .rgba8Unorm)
        let bytesPerRow = VCHelper.alignMemory(unalignedSize: width, bound: pixelRowAlignment) * 4
        
        let pagesize = Int(getpagesize())
        let allocationSize = VCHelper.alignMemory(unalignedSize: bytesPerRow * height, bound: pagesize)
        var _data: UnsafeMutableRawPointer? = nil
        let result = posix_memalign(&_data, pagesize, allocationSize)
        if result != noErr {
            throw NSError(domain: domain, code: 3, userInfo: [NSLocalizedFailureReasonErrorKey:"Failed to allocate memory"])
        }
        
        guard let data = _data,
              let context = CGContext(data: data,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo(rawValue: (CGImageAlphaInfo.premultipliedLast.rawValue)).rawValue),
              let buffer = device.makeBuffer(bytesNoCopy: data,
                                             length: allocationSize,
                                             options: .storageModeShared,
                                             deallocator: { (pointer, length) in
                
              })
        else {
            throw NSError(domain: domain, code: 4, userInfo: [:])
        }
        self.cgContext = context
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = context.width
        textureDescriptor.height = context.height
        textureDescriptor.storageMode = buffer.storageMode
        textureDescriptor.usage = .shaderRead
        
        if let _texture = buffer.makeTexture(descriptor: textureDescriptor,
                                             offset: 0,
                                             bytesPerRow: context.bytesPerRow) {
            self.texture = _texture
        } else {
            throw NSError(domain: domain, code: 5, userInfo: [NSLocalizedFailureReasonErrorKey:"Failed to make texture"])
        }
    }
    
    public func push() {
        UIGraphicsPushContext(cgContext)
    }
    
    public func pop() {
        UIGraphicsPopContext()
    }
    
}
