//
//  VCPool.swift
//  VideoClap
//
//  Created by lai001 on 2021/4/4.
//

import Foundation

public protocol VCPoolObject: NSObject {
    func reset()
}

public class VCPool<T: VCPoolObject>: NSObject {
    
    private var objects: [T] = []
    
    public init(count: Int) {
        objects = (0..<count).map { (_) -> T in
            let object = T()
            object.reset()
            return object
        }
    }
    
    public func dequeue() -> T? {
        let object = objects.first
        return object
    }
    
    public func enqueue(_ object: T) {
        object.reset()
        objects.append(object)
    }
    
    public func count() -> Int {
        return objects.count
    }
    
}
