//
//  GLImageView.swift
//  VideoClap
//
//  Created by lai001 on 2021/3/10.
//

import Foundation
import OpenGLES
import GLKit

open class GLImageView: GLKView {
    
    private var ciContext: CIContext?
    
    private var renderContentScaleFactor: CGFloat = 1
    
    private var renderInRect: CGRect = .zero
    
    open var image: CIImage? {
        didSet {
            if let _ciContext = self.ciContext, let _image = image {
                _ciContext.draw(_image, in: renderInRect, from: _image.extent)
                display()
            }
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        if let eaglContext = EAGLContext(api: .openGLES3) ?? EAGLContext(api: .openGLES2) ?? EAGLContext(api: .openGLES1) {
            self.context = eaglContext
            ciContext = CIContext(eaglContext: eaglContext)
        }
        renderContentScaleFactor = contentScaleFactor
    }
    
    public override init(frame: CGRect, context: EAGLContext) {
        super.init(frame: frame, context: context)
        ciContext = CIContext(eaglContext: context)
        renderContentScaleFactor = contentScaleFactor
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        renderInRect = self.bounds.applying(.init(scaleX: renderContentScaleFactor, y: renderContentScaleFactor))
    }
    
}
