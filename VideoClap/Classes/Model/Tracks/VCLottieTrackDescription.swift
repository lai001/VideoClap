//
//  VCLottieTrackDescription.swift
//  VideoClap
//
//  Created by lai001 on 2020/11/22.
//

import AVFoundation
import Lottie

public class VCLottieTrackDescription: VCImageTrackDescription {
    
    public var rect: VCRect {
        get {
            switch imageLayout {
            case .fit:
                return .zero
            case .fill:
                return .zero
            case .center(_):
                return .zero
            case .rect(let rect):
                return rect
            }
        }
        set {
            imageLayout = .rect(newValue)
        }
    }
    
    internal var animationView: AnimationView?
    
    internal let frame: CGRect = CGRect(origin: .zero, size: CGSize(width: 100, height: 100))
    
    internal let contentMode: UIView.ContentMode = .scaleAspectFit
    
    public override func prepare(description: VCVideoDescription) {
        super.prepare(description: description)
        if let path = mediaURL?.path, let animation = Animation.filepath(path, animationCache: LRUAnimationCache.sharedCache), animation.duration > .zero {
            self.animationView = AnimationView()
            self.animationView?.contentMode = self.contentMode
            self.animationView?.animation = animation
            self.animationView?.frame = self.frame
            self.animationView?.setNeedsDisplay()
        }
    }
    
    func animationFrame(animationPlayTime: CMTime, handler: @escaping (_ frame: CIImage?) -> Void) {
        DispatchQueue.main.async {
            guard let animationView = self.animationView, let animation = animationView.animation else {
                handler(nil)
                return
            }
            let remainder = animationPlayTime.seconds.truncatingRemainder(dividingBy: animation.duration)
            let progress = CGFloat(remainder / animation.duration)
            if progress.isNaN || progress.isInfinite {
                handler(nil)
                return
            }
            animationView.currentProgress = progress
            let bounds = animationView.layer.bounds
            let snapshotLayer = animationView.layer
            DispatchQueue.main.async {
                DispatchQueue.global().async {
                    let renderer = VCGraphicsRenderer()
                    renderer.rendererRect = bounds
                    let image = renderer.ciImage { (cgcontext) in
                        snapshotLayer.render(in: cgcontext)
                    }
                    handler(image)
                }
            }
        }
    }
    
    public override func mutableCopy(with zone: NSZone? = nil) -> Any {
        let copyObj = VCLottieTrackDescription()
        copyObj.mediaURL         = mediaURL
        copyObj.id               = id
        copyObj.timeRange        = timeRange
        copyObj.isFlipHorizontal = isFlipHorizontal
        copyObj.filterIntensity  = filterIntensity
        copyObj.lutImageURL      = lutImageURL
        copyObj.rotateRadian     = rotateRadian
        copyObj.cropedRect       = cropedRect
        copyObj.trajectory       = trajectory
        copyObj.canvasStyle      = canvasStyle
        copyObj.imageLayout      = imageLayout
        copyObj.indexPath        = indexPath
        if let animationView = self.animationView {
            let copyAnimationView = AnimationView()
            copyAnimationView.contentMode = animationView.contentMode
            copyAnimationView.animation = animationView.animation
            copyAnimationView.frame = animationView.frame
            copyAnimationView.setNeedsDisplay()
            copyObj.animationView = copyAnimationView
        }
        return copyObj
    }
    
    public override func originImage(time: CMTime, compensateTimeRange: CMTimeRange?) -> CIImage? {
        return originImage(time: time, renderSize: .zero, renderScale: 0.0, compensateTimeRange: compensateTimeRange)
    }
    
    public override func originImage(time: CMTime, renderSize: CGSize, renderScale: CGFloat, compensateTimeRange: CMTimeRange?) -> CIImage? {
        locker.object(forKey: #function).lock()
        defer {
            locker.object(forKey: #function).unlock()
        }
        var originImage: CIImage?
        let key = (mediaURL?.path ?? "") + String(format: "%.5f", time.seconds)
        if let cacheImage = VCImageCache.share.ciImage(forKey: key) {
            originImage = cacheImage
        } else {
            let group = DispatchGroup()
            group.enter()
            animationFrame(animationPlayTime: time) { (image) in
                originImage = image
                VCImageCache.share.storeImage(toMemory: image, forKey: key)
                group.leave()
            }
            group.wait()
        }
        return originImage
    }
    
}
