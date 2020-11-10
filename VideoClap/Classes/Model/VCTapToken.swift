//
//  VCTapToken.swift
//  VideoClap
//
//  Created by lai001 on 2020/11/9.
//

import Foundation
import AVFoundation

/// 使用Token 强制持用  VCAudioProcessingTapProcessProtocol对象，防止在使用MTAudioProcessingTap时 MTAudioProcessingTapCallbacks  process回调中取不到 VCAudioProcessingTapProcessProtocol 对象导致内存访问错误
public class VCTapToken {
    var processCallback: VCAudioProcessingTapProcessProtocol
    var trackID: String
    
    init(trackID: String, processCallback: VCAudioProcessingTapProcessProtocol) {
        self.trackID = trackID
        self.processCallback = processCallback
    }
}
