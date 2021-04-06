//
//  VCParticleEmitter.swift
//  VideoClap
//
//  Created by lai001 on 2021/2/18.
//

import Foundation
import CoreMedia

open class VCParticleEmitter: NSObject {
    
    public var timeRange: CMTimeRange = .zero
    
    public private(set) var particles: [VCBaseParticle] = []
    
    public var instructions: [VCParticleInstruction] = []
    
    public var time: CMTime = .zero
    
    public override init() {
        super.init()
        
    }
    
    public func update() {
        guard let instruction = instructions.first(where: { $0.timeRange.containsTime(time) }) else {
            particles = []
            return
        }
        particles = instruction.particles
        particles.forEach { (particle) in
            particle.reset()
            particle.update(systemTime: time)
        }
    }
    
}

extension VCParticleEmitter {
    
    public static func make(timeRange: CMTimeRange,
                            emitRate: Int,
                            particleLifetimeRange: ClosedRange<TimeInterval>,
                            xAccelerationRange: ClosedRange<Float>,
                            yAccelerationRange: ClosedRange<Float>,
                            startColor: UIColor,
                            endColor: UIColor,
                            center: CGPoint) -> VCParticleEmitter {
        let emitter = VCParticleEmitter()
        
        var particles: [VCBaseParticle] = []
        for start in stride(from: 0.0, to: timeRange.duration.seconds.rounded(.up), by: 1.0) {
            for _ in 0..<emitRate {
                let particle = VCBaseParticle()
                particle.timeRange = CMTimeRange(start: start, duration: TimeInterval.random(in: particleLifetimeRange))
                particle.acceleration = simd_float2(Float.random(in: xAccelerationRange), Float.random(in: yAccelerationRange))
                particle.position.initValue = center
                particle.startColor = startColor
                particle.endColor = endColor
                particles.append(particle)
            }
        }
        let instructionsTimeRanges: [CMTimeRange] = VCHelper.instructionTimeRanges(of: particles.map({ $0.timeRange }))
        var instructions: [VCParticleInstruction] = []
        
        for instructionsTimeRange in instructionsTimeRanges {
            let ins = VCParticleInstruction()
            ins.timeRange = instructionsTimeRange
            ins.particles = particles.filter({ $0.timeRange.intersection(instructionsTimeRange).isEmpty == false })
            instructions.append(ins)
        }
        
        emitter.timeRange = timeRange
        emitter.instructions = instructions
        return emitter
    }
    
}
