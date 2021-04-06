//
//  VCChildrenAudioEffectProvider2.swift
//  VideoClap
//
//  Created by lai001 on 2021/1/21.
//

import Foundation
import AVFoundation

public class VCChildrenAudioEffectProvider2: NSObject, VCAudioEffectProviderProtocol {
    
    public func handle(timeRange: CMTimeRange, inCount: CMItemCount, inFlag: MTAudioProcessingTapFlags, outBuffer: UnsafeMutablePointer<AudioBufferList>, outCount: UnsafeMutablePointer<CMItemCount>, outFlag: UnsafeMutablePointer<MTAudioProcessingTapFlags>, pcmFormat: AVAudioFormat) {
        var status = OSStatus()
        let engine = VCAudioEngine()
        let player = VCAudioNode(componentType: kAudioUnitType_Generator, componentSubType: kAudioUnitSubType_ScheduledSoundPlayer)
        let effect = VCAudioNode(componentType: kAudioUnitType_FormatConverter, componentSubType: kAudioUnitSubType_NewTimePitch)
        let output = VCAudioNode(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_GenericOutput)
        status = engine.addNode(player)
        status = engine.addNode(effect)
        status = engine.addNode(output)
        status = engine.open()
        status = engine.connect(player, to: effect)
        status = engine.connect(effect, to: output)
        status = effect.setRenderQuality(127)
        status = effect.setOfflineRender(1)
        status = player.setMaximumFramesPerSlice(AVAudioFrameCount(outCount.pointee))
        status = effect.setMaximumFramesPerSlice(AVAudioFrameCount(outCount.pointee))
        status = output.setMaximumFramesPerSlice(AVAudioFrameCount(outCount.pointee))

        var timeStamp = AudioTimeStamp()
        timeStamp.mFlags = .sampleTimeValid
        timeStamp.mSampleTime = 0
        
        var slice = ScheduledAudioSlice(mTimeStamp: timeStamp,
                                        mCompletionProc: nil,
                                        mCompletionProcUserData: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                        mFlags: AUScheduledAudioSliceFlags.scheduledAudioSliceFlag_BeganToRender,
                                        mReserved: 0,
                                        mReserved2: nil,
                                        mNumberFrames: UInt32(outCount.pointee),
                                        mBufferList: outBuffer)
        status = player.setProperty(inID: kAudioUnitProperty_ScheduleAudioSlice,
                                    inData: &slice,
                                    inDataSize: UInt32(MemoryLayout<ScheduledAudioSlice>.size))
        
        status = player.setProperty(inID: kAudioUnitProperty_ScheduleStartTimeStamp,
                                    inData: &timeStamp,
                                    inDataSize: UInt32(MemoryLayout<AudioTimeStamp>.size))

        status = effect.setParameter(inID: kNewTimePitchParam_Rate, inValue: 1.0)
        status = effect.setParameter(inID: kNewTimePitchParam_Pitch, inValue: 657.43)
        status = effect.setParameter(inID: kNewTimePitchParam_Overlap, inValue: 8.0)
        status = engine.initialize()
        status = output.start()
        status = engine.start()
        status = output.render(numberFrames: UInt32(outCount.pointee), outBuffer: outBuffer)
        status = engine.stop()
        status = engine.close()
        status = engine.uninitialize()
        status = engine.dispose()
    }
    
}
