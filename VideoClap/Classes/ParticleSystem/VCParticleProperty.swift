//
//  VCParticleProperty.swift
//  VideoClap
//
//  Created by lai001 on 2021/4/5.
//

import Foundation

public class VCParticleProperty<T>: NSObject {
    
    public var initValue: T
    public var value: T
    
    public init(initValue: T) {
        self.initValue = initValue
        self.value = initValue
        super.init()
    }
    
}
