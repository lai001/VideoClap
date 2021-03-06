//
//  VCMediaTrackDescriptionProtocol.swift
//  VideoClap
//
//  Created by lai001 on 2020/11/22.
//

import AVFoundation

public protocol VCMediaTrackDescriptionProtocol: VCScaleTrackDescriptionProtocol {
    
    var mediaURL: URL? { get set }
    
    var speed: Float { get }
    
    var associationInfo: MediaTrackAssociationInfo { get set }
}

public class MediaTrackAssociationInfo: NSObject {
    
    internal var persistentTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    internal var compositionTrack: AVMutableCompositionTrack?

    internal override init() {
        super.init()
    }
    
}

internal extension VCMediaTrackDescriptionProtocol {
    internal var persistentTrackID: CMPersistentTrackID {
        get { return associationInfo.persistentTrackID }
        set { associationInfo.persistentTrackID = newValue }
    }
    internal var compositionTrack: AVMutableCompositionTrack? {
        get { return associationInfo.compositionTrack }
        set { associationInfo.compositionTrack = newValue }
    }
}
