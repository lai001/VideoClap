//
//  CADisplayLinkProxy.swift
//  VideoClap
//
//  Created by lai001 on 2021/3/23.
//

import Foundation

/// https://stackoverflow.com/questions/44096793/how-to-set-cadisplaylink-in-swift-with-weak-reference-between-target-and-cadispl
public class CADisplayLinkProxy {

    public var displaylink: CADisplayLink?
    public var handle: ((CADisplayLink) -> Void)?

    public var isPaused: Bool? {
        get {
            return displaylink?.isPaused
        }
        set {
            displaylink?.isPaused = newValue ?? false
        }
    }
    
    public init(handle: ((CADisplayLink) -> Void)?) {
        self.handle = handle
        displaylink = CADisplayLink(target: self, selector: #selector(updateHandle))
        add()
    }
    
    deinit {
        invalidate()
    }

    @objc func updateHandle(_ link: CADisplayLink) {
        handle?(link)
    }

    public func invalidate() {
        displaylink?.isPaused = true
        displaylink?.remove(from: RunLoop.current, forMode: .common)
        displaylink?.invalidate()
        displaylink = nil
    }
    
    public func add(to runloop: RunLoop = .current, forMode mode: RunLoop.Mode = .default) {
        displaylink?.add(to: runloop, forMode: mode)
    }
    
}
