//
//  VCVideoCompositor.swift
//  VideoClap
//
//  Created by lai001 on 2020/10/22.
//

import Foundation
import GLKit
import AVFoundation

internal enum VCVideoCompositorError: Error {
    case noVideoFile(String)
    case noAudioFile(String)
    case videoIsNotPlayable(String)
    case audioIsNotPlayable(String)
    case noVideoTrack(String)
    case noAudioTrack(String)
    case internalError
}

internal class VCVideoCompositor: NSObject {
    
    internal static let EmptyVideoTrackID = CMPersistentTrackID(3000 - 1)
    
    internal static let MediaTrackIDHeader = CMPersistentTrackID(3000)
    
    internal var videoDescription: VCVideoDescription
    
    private lazy var blackVideoAsset: AVURLAsset = {
        let url = VCHelper.bundle().url(forResource: "black30s_60fps.mov", withExtension: nil) ?? URL(fileURLWithPath: "")
        return AVURLAsset(url: url)
    }()
    
    internal var requestCallbackHandler: VCRequestCallbackHandlerProtocol
    
    init(requestCallbackHandler: VCRequestCallbackHandlerProtocol, videoDescription: VCVideoDescription) {
        self.requestCallbackHandler = requestCallbackHandler
        self.videoDescription = videoDescription
    }
    
    internal func makePlayerItem(customVideoCompositorClass: AVVideoCompositing.Type? = VCVideoCompositing.self) throws -> AVPlayerItem {
        let composition = AVMutableComposition(urlAssetInitializationOptions: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let transitionDuration = videoDescription.transitions.reduce(CMTime.zero) { (result, transition) -> CMTime in
            switch transition.rangeType {
            case .overlapOrRange(_):
                return result
            case .timeRange(let timeRange):
                return result + timeRange.duration
            }
        }
        let videoDuration = estimateOtherTracksDuration() + transitionDuration
        guard let compositionTrack = self.compositionTrack(at: composition, withMediaType: .video, trackID: VCVideoCompositor.EmptyVideoTrackID) else {
            throw VCVideoCompositorError.internalError
        }
        let trackBundle = videoDescription.trackBundle
        let existVideoTrackDic = addVideoTracks(persistentTrackHeaderID: VCVideoCompositor.MediaTrackIDHeader,
                                                videoTracks: trackBundle.videoTracks,
                                                composition: composition)
        
        var audioTrackHeaderID: CMPersistentTrackID = VCVideoCompositor.MediaTrackIDHeader
        if let videoTrackTailID = existVideoTrackDic.keys.max() {
            audioTrackHeaderID = videoTrackTailID + 1
        }
        let existAudioTrackDic = addAudioTracks(persistentTrackHeaderID: audioTrackHeaderID,
                                                audioTracks: trackBundle.audioTracks,
                                                composition: composition)
        
        try addEmptyTrack(timeRange: CMTimeRange(start: .zero, duration: max(composition.duration, videoDuration)), onCompositionTrack: compositionTrack)
        
        var audioMixInputParametersGroup: [AVMutableAudioMixInputParameters] = []
        for (_, trackInfos) in existAudioTrackDic {
            for audioTrack in trackInfos {
                if let inputParameters = addAudioMix(track: audioTrack) {
                    audioMixInputParametersGroup.append(inputParameters)
                }
            }
        }
        
        var audioMix: AVMutableAudioMix?
        if audioMixInputParametersGroup.isEmpty == false {
            audioMix = AVMutableAudioMix()
            audioMix?.inputParameters = audioMixInputParametersGroup
        }
        
        var instructions = buildVideoInstruction(videoTracks: existVideoTrackDic.flatMap({ $0.value }),
                                                 audioTracks: existAudioTrackDic.flatMap({ $0.value }))
        
        if instructions.isEmpty {
            let emptyInstruction = VCVideoInstruction()
            emptyInstruction.timeRange = CMTimeRange(start: .zero, duration: videoDuration)
            emptyInstruction.requiredSourceTrackIDs = [VCVideoCompositor.EmptyVideoTrackID as NSValue]
            emptyInstruction.videoProcessProtocol = self.requestCallbackHandler
            instructions.append(emptyInstruction)
        }
        
        let videoComposition = buildVideoComposition(videoDescription: videoDescription, instructions: instructions, customVideoCompositorClass: customVideoCompositorClass)
        
        let newPlayerItem = AVPlayerItem(asset: composition)
        newPlayerItem.audioMix = audioMix
        newPlayerItem.videoComposition = videoComposition
        newPlayerItem.audioTimePitchAlgorithm = .spectral
        return newPlayerItem
    }
    
    internal func estimateOtherTracksDuration() -> CMTime {
        let trackBundle = videoDescription.trackBundle
        let tracks = trackBundle.otherTracks()
        let duration = tracks.max { (lhs, rhs) -> Bool in
            return lhs.timeRange.end < rhs.timeRange.end
        }?.timeRange.end ?? .zero
        return CMTime(seconds: duration.seconds)
    }
    
    private func canInsertTimeRange(_ timeRange: CMTimeRange, atExistingTimeRanges existingTimeRanges: [CMTimeRange]) -> Bool {
        if existingTimeRanges.isEmpty {
            return true
        }
        
        for existingTimeRange in existingTimeRanges {
            let intersection = existingTimeRange.intersection(timeRange)
            if intersection.isEmpty {
                continue
            } else {
                return false
            }
        }
        
        return true
    }
    
    private func addVideoTracks(persistentTrackHeaderID: CMPersistentTrackID,
                                videoTracks: [VCVideoTrackDescription],
                                composition: AVMutableComposition) -> [CMPersistentTrackID : [VCVideoTrackDescription]] {
        return addMediaTracks(persistentTrackHeaderID: persistentTrackHeaderID,
                              mediaTracks: videoTracks,
                              mediaType: .video,
                              composition: composition) as! [CMPersistentTrackID : [VCVideoTrackDescription]] 
    }
    
    private func addAudioTracks(persistentTrackHeaderID: CMPersistentTrackID,
                                audioTracks: [VCAudioTrackDescription],
                                composition: AVMutableComposition) -> [CMPersistentTrackID : [VCAudioTrackDescription]] {
        return addMediaTracks(persistentTrackHeaderID: persistentTrackHeaderID,
                              mediaTracks: audioTracks,
                              mediaType: .audio,
                              composition: composition) as! [CMPersistentTrackID : [VCAudioTrackDescription]]
    }
    
    private func addMediaTracks(persistentTrackHeaderID: CMPersistentTrackID,
                                mediaTracks: [VCMediaTrackDescriptionProtocol],
                                mediaType: AVMediaType,
                                composition: AVMutableComposition) -> [CMPersistentTrackID : [VCMediaTrackDescriptionProtocol]] {
        
        var persistentTrackID = persistentTrackHeaderID
        var existTrackInfoDic: [CMPersistentTrackID : [VCMediaTrackDescriptionProtocol]] = [:]
        let sortedMediaTracks = mediaTracks.sorted { (lhs, rhs) -> Bool in
            return lhs.timeRange.start < rhs.timeRange.start
        }
        for mediaTrack in sortedMediaTracks {
            if let mediaURL = mediaTrack.mediaURL {
                let asset = AVURLAsset(url: mediaURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                if let bestVideoTrack = asset.tracks(withMediaType: mediaType).first, let assetDuration = bestVideoTrack.asset?.duration {
                    if let compositionTrack = composition.track(withTrackID: persistentTrackID) {
                        let existTimeRanges = compositionTrack.segments.filter({ $0.isEmpty == false }).map({ $0.timeMapping.target })
                        if self.canInsertTimeRange(mediaTrack.timeRange, atExistingTimeRanges: existTimeRanges) {
                            
                        } else {
                            persistentTrackID += 1
                        }
                    }
                    
                    if let compositionTrack = self.compositionTrack(at: composition, withMediaType: mediaType, trackID: persistentTrackID) {
                        do {
                            var fixStart: CMTime = .zero
                            var fixEnd: CMTime = .zero
                            fixStart = min(max(CMTime.zero, mediaTrack.timeMapping.source.start), assetDuration)
                            fixEnd = min(max(fixStart, mediaTrack.timeMapping.source.end), assetDuration)
                            
                            mediaTrack.timeMapping.source = CMTimeRange(start: fixStart, end: fixEnd)
                            
                            try compositionTrack.insertTimeRange(mediaTrack.timeMapping.source, of: bestVideoTrack, at: mediaTrack.timeMapping.target.start)
                            let scaledTimeRange: CMTimeRange = CMTimeRange(start: mediaTrack.timeMapping.target.start, duration: mediaTrack.timeMapping.source.duration)
                            compositionTrack.scaleTimeRange(scaledTimeRange, toDuration: mediaTrack.timeMapping.target.duration)
                            mediaTrack.persistentTrackID = persistentTrackID
                            mediaTrack.compositionTrack = compositionTrack
                            if var trackInfos = existTrackInfoDic[persistentTrackID] {
                                trackInfos.append(mediaTrack)
                                existTrackInfoDic[persistentTrackID] = trackInfos
                            } else {
                                existTrackInfoDic[persistentTrackID] = [mediaTrack]
                            }
                        } catch let error {
                            log.error(error)
                        }
                    }
                }
            }
        }
        return existTrackInfoDic
    }
    
    private func compositionTrack(at composition: AVMutableComposition, withMediaType mediaType: AVMediaType, trackID: CMPersistentTrackID) -> AVMutableCompositionTrack? {
        var optionalCompositionTrack = composition.track(withTrackID: trackID)
        if optionalCompositionTrack == nil {
            optionalCompositionTrack = composition.addMutableTrack(withMediaType: mediaType, preferredTrackID: trackID)
        }
        return optionalCompositionTrack
    }
    
    private func buildVideoInstruction(videoTracks: [VCVideoTrackDescription], audioTracks: [VCAudioTrackDescription]) -> [VCVideoInstruction] {
        let locker = VCLocker()
        let trackBundle = videoDescription.trackBundle
        let imageTracks = trackBundle.imageTracks
        
        var transitions: [VCTransition] = []
        
        (videoDescription.transitions as NSArray).enumerateObjects(options: .concurrent) { (obj, index, outStop) in
            guard let transition = obj as? VCTransition else { return }
            transition.timeRange = nil
            guard let fromTrack = transition.fromTrack, let toTrack = transition.toTrack/*, fromTrack.timeRange.end >= toTrack.timeRange.start*/ else { return }
            switch transition.rangeType {
            case .overlapOrRange(let range):
                if fromTrack.timeRange.end == toTrack.timeRange.start {
                    let start: CMTime = CMTime(seconds: fromTrack.timeRange.end.seconds - fromTrack.timeRange.duration.seconds * Double(range.left))
                    let end: CMTime = CMTime(seconds: toTrack.timeRange.start.seconds + toTrack.timeRange.duration.seconds * Double(range.right))
                    transition.timeRange = CMTimeRange(start: start, end: end)
                    transition.setupCompensateTimeRange()
                    locker.object(forKey: "transitions").lock()
                    transitions.append(transition)
                    locker.object(forKey: "transitions").unlock()
                } else if fromTrack.timeRange.end > toTrack.timeRange.start {
                    transition.timeRange = CMTimeRange(start: toTrack.timeRange.start, end: fromTrack.timeRange.end)
                    transition.setupCompensateTimeRange()
                    locker.object(forKey: "transitions").lock()
                    transitions.append(transition)
                    locker.object(forKey: "transitions").unlock()
                }
                
            case .timeRange(let timeRange):
                transition.timeRange = timeRange
                transition.setupCompensateTimeRange()
                locker.object(forKey: "transitions").lock()
                transitions.append(transition)
                locker.object(forKey: "transitions").unlock()
            }
        }
        
        var instructions: [VCVideoInstruction] = []
        var timeRanges: [CMTimeRange] = []
        timeRanges = imageTracks.map({ $0.timeRange })
        timeRanges += videoTracks.map({ $0.timeRange })
        timeRanges += audioTracks.map({ $0.timeRange })
        timeRanges += transitions.compactMap({ $0.timeRange })
        timeRanges = VCHelper.instructionTimeRanges(of: timeRanges)
        
        (timeRanges as NSArray).enumerateObjects(options: .concurrent) { (obj: Any, _, _) in
            guard let timeRange = obj as? CMTimeRange else { return }
            let trackBundle = VCTrackBundle()
            let instruction = VCVideoInstruction()
            instruction.trackBundle = trackBundle
            
            trackBundle.imageTracks = imageTracks.filter({ $0.timeRange.intersection(timeRange).isEmpty == false })
            trackBundle.videoTracks = videoTracks.filter({ $0.timeMapping.target.intersection(timeRange).isEmpty == false })
            trackBundle.audioTracks = audioTracks.filter({ $0.timeMapping.target.intersection(timeRange).isEmpty == false })
            
            if trackBundle.videoTracks.isEmpty {
                instruction.requiredSourceTrackIDs = [VCVideoCompositor.EmptyVideoTrackID as NSValue]
            } else {
                instruction.requiredSourceTrackIDsDic = trackBundle.videoTracks.reduce([:]) { (result, trackInfo: VCVideoTrackDescription) -> [CMPersistentTrackID : VCVideoTrackDescription] in
                    var mutable = result
                    mutable[trackInfo.persistentTrackID] = trackInfo
                    return mutable
                }
                instruction.requiredSourceTrackIDs = instruction.requiredSourceTrackIDsDic.map({ $0.key as NSValue })
            }
            
            instruction.transitions = transitions.filter { (transition) -> Bool in
                if let _timeRange = transition.timeRange {
                    return _timeRange.intersection(timeRange).isEmpty == false
                } else {
                    return false
                }
            }
            instruction.timeRange = timeRange
            instruction.videoProcessProtocol = self.requestCallbackHandler
            
            locker.object(forKey: "instructions").lock()
            instructions.append(instruction)
            locker.object(forKey: "instructions").unlock()
        }
        
        instructions = instructions.sorted { (lhs, rhs) -> Bool in
            return lhs.timeRange.start < rhs.timeRange.start
        }
        
        return instructions
    }
    
    private func buildVideoComposition(videoDescription: VCVideoDescription, instructions: [VCVideoInstruction], customVideoCompositorClass: AVVideoCompositing.Type? = VCVideoCompositing.self) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        #if !targetEnvironment(simulator)
        if #available(iOS 10.0, *) {
        videoComposition.colorPrimaries = videoDescription.colorPrimaries
        videoComposition.colorTransferFunction = videoDescription.colorTransferFunction
        videoComposition.colorYCbCrMatrix = videoDescription.colorYCbCrMatrix
        }
        #endif
        
        videoComposition.frameDuration = CMTime(seconds: 1 / videoDescription.fps, preferredTimescale: 600)
        videoComposition.instructions = instructions
        videoComposition.customVideoCompositorClass = customVideoCompositorClass
        videoComposition.renderSize = videoDescription.renderSize
        videoComposition.renderScale = Float(videoDescription.renderScale)
        return videoComposition
    }
    
    private func addAudioMix(track: VCAudioTrackDescription) -> AVMutableAudioMixInputParameters? {
        if track.audioVolumeRampDescriptions.isEmpty && track.audioEffectProvider == nil {
            return nil
        }
        guard let compositionTrack = track.compositionTrack else { return nil }
        let inputParams = AVMutableAudioMixInputParameters(track: compositionTrack)
        inputParams.trackID = track.persistentTrackID
        var existTimeRanges: [CMTimeRange] = []
        for audioVolumeRampDescription in track.audioVolumeRampDescriptions {
            guard audioVolumeRampDescription.timeRange.isValid else {
                continue
            }
            
            for existTimeRange in existTimeRanges {
                if existTimeRange.intersection(audioVolumeRampDescription.timeRange).isEmpty == false {
                    continue
                }
            }
            
            inputParams.setVolumeRamp(fromStartVolume: audioVolumeRampDescription.startVolume,
                                      toEndVolume: audioVolumeRampDescription.endVolume,
                                      timeRange: audioVolumeRampDescription.timeRange)
            existTimeRanges.append(audioVolumeRampDescription.timeRange)
        }
        
        do {
            let token = VCTapToken(processCallback: requestCallbackHandler, audioTrack: track)
            try inputParams.setAudioProcessingTap(token: token)
        } catch let error {
            log.error(error)
        }
        
        return inputParams
    }
    
    private func addEmptyTrack(timeRange: CMTimeRange, onCompositionTrack compositionTrack: AVMutableCompositionTrack) throws {
        guard let blackVideoTrack = blackVideoAsset.tracks(withMediaType: .video).first else {
            throw VCVideoCompositorError.internalError
        }
        struct InsertDescription {
            let duraionValue: CMTimeValue
            let insertTimeValue: CMTimeValue
        }
        var insertDescriptions: [InsertDescription] = []
        
        var timeRangeDurationValue = CMTime(seconds: timeRange.duration.seconds).value
        let blackVideoDurationValue = CMTime(seconds: blackVideoAsset.duration.seconds).value
        if blackVideoDurationValue <= .zero {
            throw VCVideoCompositorError.internalError
        }
        var append: Bool = false
        while timeRangeDurationValue - blackVideoDurationValue > 0 {
            let duraionValue: CMTimeValue = blackVideoDurationValue
            var insertTimeValue: CMTimeValue = 0
            if let lastInsertTimeValue = insertDescriptions.last?.insertTimeValue {
                insertTimeValue = lastInsertTimeValue + blackVideoDurationValue
            } else {
                insertTimeValue = timeRange.start.value
            }
            
            let insertDescription = InsertDescription(duraionValue: duraionValue, insertTimeValue: insertTimeValue)
            insertDescriptions.append(insertDescription)
            timeRangeDurationValue -= blackVideoDurationValue
            append = true
        }
        
        if append {
            let insertDescription = InsertDescription(duraionValue: timeRangeDurationValue,
                                                      insertTimeValue: (insertDescriptions.last?.insertTimeValue ?? 0) + timeRangeDurationValue)
            insertDescriptions.append(insertDescription)
        } else {
            let insertDescription = InsertDescription(duraionValue: timeRangeDurationValue,
                                                      insertTimeValue: timeRange.start.value)
            insertDescriptions.append(insertDescription)
        }
        
        for insertDescription in insertDescriptions {
            let range = CMTimeRange(start: .zero, duration: CMTime(value: insertDescription.duraionValue, timescale: 600))
            let time = CMTime(value: insertDescription.insertTimeValue, timescale: 600)
            try compositionTrack.insertTimeRange(range, of: blackVideoTrack, at: time)
        }
    }
    
}

extension VCVideoCompositor: VCMediaServicesObserver {
    
    func mediaServicesWereResetNotification(_ sender: Notification) {
        let url = VCHelper.bundle().url(forResource: "black30s.mov", withExtension: nil) ?? URL(fileURLWithPath: "")
        blackVideoAsset = AVURLAsset(url: url)
    }
    
    func mediaServicesWereLostNotification(_ sender: Notification) {
        
    }
    
}
