//
//  VCParticleEmitterRenderer.swift
//  VideoClap
//
//  Created by lai001 on 2021/4/5.
//

import Foundation

open class VCParticleEmitterRenderer: NSObject {
    
    private let renderer = VCGraphicsRenderer()
    
    public var rendererRect: CGRect = .zero {
        didSet {
            renderer.rendererRect = rendererRect
        }
    }
    
    public var scale: CGFloat = 1.0 {
        didSet {
            renderer.scale = scale
        }
    }
    
    public var opaque: Bool = false {
        didSet {
            renderer.opaque = opaque
        }
    }
    
    public var emitter: VCParticleEmitter?
    
    public init(emitter: VCParticleEmitter? = nil) {
        super.init()
        self.emitter = emitter
    }
    
    public func render(image: UIImage) -> UIImage? {
        guard let emitter = self.emitter else { return nil }
        let offsetX: CGFloat = image.size.width / 2
        let offsetY: CGFloat = image.size.height / 2
        let image = self.renderer.image { (context: CGContext) in
            
            for particle in emitter.particles {
//                particle.color.setFill()
//                let path = UIBezierPath(arcCenter: particle.position.value, radius: 5.0, startAngle: 0.0, endAngle: .pi * 2, clockwise: true)
//                path.close()
//                path.fill()
                
                let point = CGPoint(x: particle.position.value.x - offsetX, y: particle.position.value.y - offsetY)
//                image.draw(at: point, blendMode: .normal, alpha: CIColor(color: particle.color).alpha)
                VCHelper.imageWithTintColor(particle.color, image: image).draw(at: point)
            }
        }
        return image
    }
    
}
