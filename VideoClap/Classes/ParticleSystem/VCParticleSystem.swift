//
//  VCParticleSystem.swift
//  VideoClap
//
//  Created by lai001 on 2021/2/18.
//

import Foundation
import CoreMedia

open class VCParticleSystem: NSObject {
    
    public var emitters: [VCParticleEmitter] = []
    
    public var timeRange: CMTimeRange = .zero
    
    public var time: CMTime = .zero
    
    public override init() {
        super.init()
    }
    
}
