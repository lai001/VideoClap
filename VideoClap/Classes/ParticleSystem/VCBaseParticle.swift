//
//  VCBaseParticle.swift
//  VideoClap
//
//  Created by lai001 on 2021/2/18.
//

import Foundation
import CoreMedia

open class VCBaseParticle: NSObject {
    
    public var position: VCParticleProperty<CGPoint> = VCParticleProperty(initValue: CGPoint())
    
    public var startColor: UIColor = .black
    
    public var endColor: UIColor = .black
    
    public var color: UIColor = .black
    
    public var acceleration: simd_float2 = simd_float2()
    
    public var timeRange: CMTimeRange = .zero
    
    public func reset() {
        position.value = position.initValue
        color = .black
    }
    
    public func update(systemTime: CMTime) {
        let x = CGFloat(systemTime.seconds - timeRange.start.seconds) * CGFloat(acceleration.x) + position.initValue.x
        let y = CGFloat(systemTime.seconds - timeRange.start.seconds) * CGFloat(acceleration.y) + position.initValue.y
        position.value = CGPoint(x: x, y: y)
        
        let progress = (systemTime.seconds - timeRange.start.seconds) / timeRange.duration.seconds
        
        let startCIColor = CIColor(color: startColor)
        let endCIColor = CIColor(color: endColor)
        
        let red = startCIColor.red + (endCIColor.red - startCIColor.red) * CGFloat(progress)
        let blue = startCIColor.blue + (endCIColor.blue - startCIColor.blue) * CGFloat(progress)
        let green = startCIColor.green + (endCIColor.green - startCIColor.green) * CGFloat(progress)
        let alpha = startCIColor.alpha + (endCIColor.alpha - startCIColor.alpha) * CGFloat(progress)
        color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
