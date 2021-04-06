//
//  VCTransition.swift
//  VideoClap
//
//  Created by lai001 on 2020/11/22.
//

import AVFoundation

public enum TransitionTimeRangeType {
    case overlapOrRange(VCRange)
    case timeRange(CMTimeRange)
}

open class VCTransition: NSObject, NSCopying, NSMutableCopying {
    
    public var fromTrack: VCImageTrackDescription?
    
    public var toTrack: VCImageTrackDescription?
    
    public var rangeType = TransitionTimeRangeType.overlapOrRange(VCRange(left: 0.5, right: 0.5))
    
    public internal(set) var timeRange: CMTimeRange?
    
    public var transition: VCTransitionProtocol = VCAlphaTransition()
    
    public init(fromTrack: VCImageTrackDescription? = nil, toTrack: VCImageTrackDescription? = nil, rangeType: TransitionTimeRangeType = .overlapOrRange(VCRange(left: 0.5, right: 0.5)), transition: VCTransitionProtocol = VCAlphaTransition()) {
        self.fromTrack = fromTrack
        self.toTrack = toTrack
        self.rangeType = rangeType
        self.transition = transition
    }
    
    func setupCompensateTimeRange() {
        guard let fromTrack = self.fromTrack else { return }
        guard let toTrack = self.toTrack else { return }
        guard var timeRange = self.timeRange else { return }
        timeRange = fromTrack.timeRange.union(toTrack.timeRange).intersection(timeRange)
        fromTrack.trackCompensateTimeRange = CMTimeRange(start: fromTrack.timeRange.start, end: timeRange.end)
        toTrack.trackCompensateTimeRange = CMTimeRange(start: timeRange.start, end: toTrack.timeRange.end)
    }
    
    open func transition(compositionTime: CMTime, fromImage: CIImage?, toImage: CIImage?, renderSize: CGSize, renderScale: CGFloat) -> CIImage? {
        
        guard let fromTrack = self.fromTrack else { return nil }
        guard let toTrack = self.toTrack else { return nil }
        guard var timeRange = self.timeRange else { return nil }
        timeRange = fromTrack.timeRange.union(toTrack.timeRange).intersection(timeRange)
        
        let progress = (compositionTime.seconds - timeRange.start.seconds) / timeRange.duration.seconds
        if progress.isNaN {
            return nil
        }
        
        var _fromImage: CIImage? = fromImage
        if _fromImage == nil {
            let compensateTimeRange = fromTrack.trackCompensateTimeRange
            if let sourceFrame = fromTrack.originImage(time: fromTrack.timeRange.end, renderSize: renderSize, renderScale: renderScale, compensateTimeRange: compensateTimeRange) {
                _fromImage = fromTrack.compositionImage(sourceFrame: sourceFrame,
                                                        compositionTime: compositionTime,
                                                        renderSize: renderSize,
                                                        renderScale: renderScale,
                                                        compensateTimeRange: compensateTimeRange)
            }
        }
        
        var _toImage: CIImage? = toImage
        if _toImage == nil {
            let compensateTimeRange = toTrack.trackCompensateTimeRange
            if let sourceFrame = toTrack.originImage(time: toTrack.timeRange.start, renderSize: renderSize, renderScale: renderScale, compensateTimeRange: compensateTimeRange) {
                _toImage = toTrack.compositionImage(sourceFrame: sourceFrame,
                                                    compositionTime: compositionTime,
                                                    renderSize: renderSize,
                                                    renderScale: renderScale,
                                                    compensateTimeRange: compensateTimeRange)
            }
        }
        let blackImage = VCHelper.image(color: .black, size: renderSize.scaling(renderScale))
        if let _fromImage = _fromImage, let _toImage = _toImage {
            return transition.transition(renderSize: renderSize.scaling(renderScale),
                                         progress: Float(progress),
                                         fromImage: _fromImage.composited(over: blackImage),
                                         toImage: _toImage.composited(over: blackImage))
        }
        return nil
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    open func mutableCopy(with zone: NSZone? = nil) -> Any {
        let copyObj = VCTransition(fromTrack: fromTrack, toTrack: toTrack, rangeType: rangeType, transition: transition)
        copyObj.timeRange = timeRange
        return copyObj
    }
    
}
