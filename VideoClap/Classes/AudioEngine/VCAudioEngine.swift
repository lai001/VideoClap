//
//  VCAudioEngine.swift
//  VideoClap
//
//  Created by lai001 on 2021/1/23.
//

import AVFoundation

public class VCAudioEngine: NSObject {
    
    public private(set) var graph: AUGraph?
    
    public override init() {
        super.init()
        NewAUGraph(&graph)
    }
    
    @discardableResult public func addNode(_ node: VCAudioNode) -> OSStatus {
        guard let graph = self.graph else { return -1 }
        var status = OSStatus()
        var unit: AudioUnit?
        var socket = AUNode()
        status = AUGraphAddNode(graph, &node.audioComponentDescription, &socket)
        if isOpen() == false {
            open()
        }
        status = AUGraphNodeInfo(graph, socket, nil, &unit)
        if unit != nil {
            node.addTo(engine: self, socket: socket, unit: unit.unsafelyUnwrapped)
        }
        return status
    }
    
    @discardableResult public func connect(_ node0: VCAudioNode, bus0: UInt32 = 0, to node1: VCAudioNode, bus1: UInt32 = 0, format: AVAudioFormat? = nil) -> OSStatus {
        guard let graph = self.graph else { return -1 }
        var status = OSStatus()
        status = AUGraphConnectNodeInput(graph, node0.socket, bus0, node1.socket, bus1)
        if let format = format {
            let dataSize = UInt32(MemoryLayout<UInt32>.size)
            status = node0.setProperty(inID: kAudioUnitProperty_StreamFormat,
                                       inScope: kAudioUnitScope_Global,
                                       inElement: 0,
                                       inData: format.streamDescription,
                                       inDataSize: dataSize)
            
            status = node1.setProperty(inID: kAudioUnitProperty_StreamFormat,
                                       inScope: kAudioUnitScope_Global,
                                       inElement: 0,
                                       inData: format.streamDescription,
                                       inDataSize: dataSize)
        }
        return status
    }
    
    @discardableResult public func initialize() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return AUGraphInitialize(graph)
    }
    
    @discardableResult public func isInitialized() -> Bool {
        guard let graph = self.graph else { return false }
        var status = OSStatus()
        var result = DarwinBoolean(true)
        status = AUGraphIsInitialized(graph, &result)
        return status == noErr && result.boolValue == true
    }
    
    @discardableResult public func open() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return AUGraphOpen(graph)
    }
    
    @discardableResult public func isOpen() -> Bool {
        guard let graph = self.graph else { return false }
        var status = OSStatus()
        var result = DarwinBoolean(true)
        status = AUGraphIsOpen(graph, &result)
        return status == noErr && result.boolValue == true
    }
    
    @discardableResult public func isRunning() -> Bool {
        guard let graph = self.graph else { return false }
        var status = OSStatus()
        var result = DarwinBoolean(true)
        status = AUGraphIsRunning(graph, &result)
        return status == noErr && result.boolValue == true
    }
    
    @discardableResult public func close() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return AUGraphClose(graph)
    }
    
    @discardableResult public func dispose() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return DisposeAUGraph(graph)
    }
    
    @discardableResult public func start() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return AUGraphStart(graph)
    }
    
    @discardableResult public func stop() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return AUGraphStop(graph)
    }
    
    @discardableResult public func uninitialize() -> OSStatus {
        guard let graph = self.graph else { return -1 }
        return AUGraphUninitialize(graph)
    }
    
}
