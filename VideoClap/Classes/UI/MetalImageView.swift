//
//  MetalImageView.swift
//  VideoClap
//
//  Created by lai001 on 2021/3/9.
//

import Foundation
import Metal
import MetalKit
import AVFoundation

open class MetalImageView: MTKView {
    
    public enum ContentMode {
        case scaleAspectFit
        case scaleToFill
    }
    
    open var image: CIImage? {
        didSet {
            if let image = self.image {
                if let texture = cacheOrNewTexture(size: image.extent.size) {
                    drawableSize = CGSize(width: texture.width, height: texture.height)
                    context.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
                    let mode = metalContentMode
                    self.metalContentMode = mode
                }
            } else {
                self.texture = nil
                let mode = metalContentMode
                self.metalContentMode = mode
            }
        }
    }
    
    lazy var context: CIContext = {
        var context: CIContext
        if #available(iOS 13.0, *), let queue = MetalDevice.share.commandQueue {
            context = CIContext(mtlCommandQueue: queue)
        } else if let device = MetalDevice.share.device {
            context = CIContext(mtlDevice: device)
        } else {
            context = CIContext.share
        }
        return context
    }()
    
    lazy var imageVertexs: [ImageVertex] = {
        var imageVertexs: [ImageVertex] = []
        imageVertexs.append(ImageVertex(position: simd_float2(1.0, 1.0), textureCoordinate: simd_float2(1.0, 1.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(-1.0, 1.0), textureCoordinate: simd_float2(0.0, 1.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(-1.0, -1.0), textureCoordinate: simd_float2(0.0, 0.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(1.0, 1.0), textureCoordinate: simd_float2(1.0, 1.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(-1.0, -1.0), textureCoordinate: simd_float2(0.0, 0.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(1.0, -1.0), textureCoordinate: simd_float2(1.0, 0.0)))
        return imageVertexs
    }()
    
    var vertexBuffer: MTLBuffer?
    
    var pipelineState: MTLRenderPipelineState?
    
    var texture: MTLTexture?
    
    public var metalContentMode: MetalImageView.ContentMode = .scaleToFill {
        didSet {
            if let texture = self.texture {
                switch metalContentMode {
                case .scaleAspectFit:
                    fit(imageSize: CGSize(width: CGFloat(texture.width), height: CGFloat(texture.height)))
                case .scaleToFill:
                    fill()
                }
            }
        }
    }
    
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: MetalDevice.share.device)
        backgroundColor = .clear
        initPipelineState()
        makeVertexBuffer()
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initPipelineState() {
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Image Render Pipeline"
        pipelineStateDescriptor.sampleCount = self.sampleCount
        pipelineStateDescriptor.vertexFunction = MetalDevice.share.makeFunction(name: "imageVertexShader")
        pipelineStateDescriptor.fragmentFunction = MetalDevice.share.makeFunction(name: "imageFragmentShader")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat
        if #available(iOS 11.0, *) {
            pipelineStateDescriptor.vertexBuffers[0].mutability = .immutable
        }
        do {
            pipelineState = try MetalDevice.share.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            log.error(error)
        }
    }
    
    func fit(imageSize: CGSize) {
        let viewportSize = self.bounds.size
        let textureCoordinateBounds = CGRect(x: -1, y: -1, width: 2, height: 2)
        let t = CGAffineTransform(scaleX: viewportSize.height / viewportSize.width, y: 1.0)
        let aspectSize = imageSize.applying(t)
        let aspectRect = AVMakeRect(aspectRatio: aspectSize, insideRect: textureCoordinateBounds)
        let topLeft = simd_float2(Float(aspectRect.origin.x), Float(aspectRect.origin.y + aspectRect.size.height))
        let topRight = simd_float2(Float(aspectRect.origin.x + aspectRect.size.width), Float(aspectRect.origin.y + aspectRect.size.height))
        let bottomLeft = simd_float2(Float(aspectRect.origin.x), Float(aspectRect.origin.y))
        let bottomRight = simd_float2(Float(aspectRect.origin.x + aspectRect.size.width), Float(aspectRect.origin.y))
        imageVertexs = []
        imageVertexs.append(ImageVertex(position: topRight, textureCoordinate: simd_float2(1.0, 1.0)))
        imageVertexs.append(ImageVertex(position: topLeft, textureCoordinate: simd_float2(0.0, 1.0)))
        imageVertexs.append(ImageVertex(position: bottomLeft, textureCoordinate: simd_float2(0.0, 0.0)))
        imageVertexs.append(ImageVertex(position: topRight, textureCoordinate: simd_float2(1.0, 1.0)))
        imageVertexs.append(ImageVertex(position: bottomLeft, textureCoordinate: simd_float2(0.0, 0.0)))
        imageVertexs.append(ImageVertex(position: bottomRight, textureCoordinate: simd_float2(1.0, 0.0)))
        makeVertexBuffer()
    }
    
    func fill() {
        imageVertexs = []
        imageVertexs.append(ImageVertex(position: simd_float2(1.0, 1.0), textureCoordinate: simd_float2(1.0, 1.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(-1.0, 1.0), textureCoordinate: simd_float2(0.0, 1.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(-1.0, -1.0), textureCoordinate: simd_float2(0.0, 0.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(1.0, 1.0), textureCoordinate: simd_float2(1.0, 1.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(-1.0, -1.0), textureCoordinate: simd_float2(0.0, 0.0)))
        imageVertexs.append(ImageVertex(position: simd_float2(1.0, -1.0), textureCoordinate: simd_float2(1.0, 0.0)))
    }
    
    func makeVertexBuffer() {
        guard imageVertexs.count != 0 else {
            return
        }
        vertexBuffer = MetalDevice.share.makeBuffer(bytes: imageVertexs,
                                                    length: imageVertexs.count * MemoryLayout<ImageVertex>.size,
                                                    options: [])
    }
    
    public func cacheOrNewTexture(size: CGSize) -> MTLTexture? {
        if let _texture = self.texture {
            if _texture.height == Int(size.height) && _texture.width == Int(size.width) {
                
            } else {
                self.texture = MetalDevice.share.makeTexture(width: Int(size.width), height: Int(size.height))
            }
        } else {
            self.texture = MetalDevice.share.makeTexture(width: Int(size.width), height: Int(size.height))
        }
        return self.texture
    }
    
    open func redraw() {
        draw(in: self)
    }
    
}

extension MetalImageView: MTKViewDelegate {
    
    open func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    open func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.depthAttachment.loadAction = .dontCare
        renderPassDescriptor.stencilAttachment.loadAction = .dontCare
        guard let commandBuffer = MetalDevice.share.makeCommandBuffer() else { return }
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        guard let pipelineState = pipelineState else { return }
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0,
                                     vertexCount: imageVertexs.count,
                                     instanceCount: imageVertexs.count / 3)
        renderEncoder.endEncoding()
        commandBuffer.addScheduledHandler { _ in
            drawable.present()
        }
        commandBuffer.commit()
        draw()
    }
    
}
