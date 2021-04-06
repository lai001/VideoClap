//
//  VCVideoOutputRenderer.swift
//  VideoClap
//
//  Created by lai001 on 2021/4/3.
//

import UIKit

public protocol VCVideoOutputRenderer: UIView {
    var pixelBuffer: CVPixelBuffer? { get set }
}

open class VCVideoOutputMetalRenderView: MetalImageView, VCVideoOutputRenderer {
    
    open var pixelBuffer: CVPixelBuffer? {
        didSet {
            if let pixelBuffer = self.pixelBuffer {
                image = CIImage(cvPixelBuffer: pixelBuffer)
            } else {
                image = nil
            }
            redraw()
        }
    }
    
}

open class VCVideoOutputGLRenderView: GLImageView, VCVideoOutputRenderer {
    
    open var pixelBuffer: CVPixelBuffer? {
        didSet {
            if let pixelBuffer = self.pixelBuffer {
                image = CIImage(cvPixelBuffer: pixelBuffer)
            } else {
                image = nil
            }
        }
    }
    
}
