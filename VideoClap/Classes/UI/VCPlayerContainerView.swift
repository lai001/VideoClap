//
//  VCPlayerContainerView.swift
//  VideoClap
//
//  Created by lai001 on 2021/1/23.
//

import AVFoundation

open class VCPlayerContainerView: UIView, VCRealTimeRenderTarget, AVPlayerItemOutputPullDelegate {
    
    open var compositorClass: VCVideoCompositing.Type? = VCVideoCompositing.self
    
    public weak var player: VCPlayer?
    
    private var displayLinkProxy: CADisplayLinkProxy?
    
    private var playerItemVideoOutput: AVPlayerItemVideoOutput?
    
    private lazy var renderView: VCVideoOutputRenderer = {
        #if targetEnvironment(simulator)
        let view = VCVideoOutputMetalRenderView(frame: .zero)
        #else
        let view = VCVideoOutputGLRenderView(frame: .zero)
        #endif
        return view
    }()
    
    public convenience init(player: VCPlayer? = nil) {
        self.init(frame: .zero, player: player)
    }
    
    public init(frame: CGRect, player: VCPlayer? = nil) {
        self.player = player
        super.init(frame: frame)
        addSubview(renderView)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopTimer()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        renderView.frame = fitRect()
    }
    
    func stopTimer() {
        displayLinkProxy?.isPaused = true
        displayLinkProxy?.invalidate()
        displayLinkProxy = nil
    }
    
    func startTimer(playerItem: AVPlayerItem) {
        let proxy = CADisplayLinkProxy { [weak self] link in
            guard let self = self else { return }
            self.displayLinkTick(link)
        }
        proxy.isPaused = true
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: VCVideoCompositing.defaultRequiredPixelBufferAttributesForRenderContext)
        output.setDelegate(self, queue: DispatchQueue.main)
        output.requestNotificationOfMediaDataChange(withAdvanceInterval: 1.0 / (self.player?.videoDescription.fps ?? 24.0))
        playerItem.add(output)
        displayLinkProxy = proxy
        playerItemVideoOutput = output
    }
    
    @objc func displayLinkTick(_ link: CADisplayLink) {
        guard let videoOutput = playerItemVideoOutput else { return }
        let hostTime = link.timestamp + link.duration
        let itemTime = videoOutput.itemTime(forHostTime: hostTime)
        if videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
           let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
            renderView.pixelBuffer = pixelBuffer
        }
    }
    
    public func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        displayLinkProxy?.isPaused = false
    }
    
    public func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        if let link = displayLinkProxy?.displaylink {
            displayLinkTick(link)
        }
    }
    
    public func didReplacePlayerItem(_ playerItem: AVPlayerItem?) {
        guard player != nil else {
            return
        }
        stopTimer()
        if let _playerItem = playerItem {
            startTimer(playerItem: _playerItem)
        }
    }
    
    public func onPause() {
        displayLinkProxy?.isPaused = true
    }
    
    public func onPlay() {
        displayLinkProxy?.isPaused = false
    }
    
    public func fitRect() -> CGRect {
        if let _player = self.player {
            let rect = AVMakeRect(aspectRatio: _player.videoDescription.renderSize, insideRect: self.bounds)
            guard rect.origin.x.isNaN == false,
                  rect.origin.y.isNaN == false,
                  rect.size.width.isNaN == false,
                  rect.size.height.isNaN == false
            else {
                return .zero
            }
            return rect
        }
        return .zero
    }
    
    open func draw(compositionTime: CMTime, images: [String : CIImage], blackImage: CIImage, renderSize: CGSize, renderScale: CGFloat) -> CIImage? {
        var finalFrame: CIImage?
        finalFrame = images.sorted { (lhs, rhs) -> Bool in
            return lhs.value.indexPath > rhs.value.indexPath
        }.reduce(finalFrame) { (result, args: (key: String, value: CIImage)) -> CIImage? in
            return result?.composited(over: args.value) ?? args.value
        }
        finalFrame = finalFrame?.composited(over: blackImage) ?? blackImage
        if var ciImage = finalFrame {
            ciImage = ciImage.cropped(to: CGRect(origin: .zero, size: renderSize.scaling(renderScale)))
            return ciImage
        }
        return nil
    }
    
}

open class VCCustomRenderView: VCPlayerContainerView {
    
    public override init(frame: CGRect, player: VCPlayer? = nil) {
        super.init(frame: frame, player: player)
        compositorClass = VCRealTimeRenderVideoCompositing.self
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func didReplacePlayerItem(_ playerItem: AVPlayerItem?) {
        
    }
    
    open override func onPlay() {
        
    }
    
    open override func onPause() {
        
    }
    
}

open class VCOpenglPlayerContainerView: VCCustomRenderView {
    
    lazy var glkView: GLImageView = {
        let view = GLImageView(frame: .zero)
        return view
    }()
    
    public override init(frame: CGRect, player: VCPlayer? = nil) {
        super.init(frame: frame, player: player)
        addSubview(glkView)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        glkView.frame = fitRect()
    }
    
    open override func draw(compositionTime: CMTime, images: [String : CIImage], blackImage: CIImage, renderSize: CGSize, renderScale: CGFloat) -> CIImage? {
        guard let ciImage = super.draw(compositionTime: compositionTime, images: images, blackImage: blackImage, renderSize: renderSize, renderScale: renderScale) else {
            return nil
        }
        glkView.image = ciImage
        return nil
    }
    
}

open class VCMetalPlayerContainerView: VCCustomRenderView {
    
    internal lazy var renderView: MetalImageView = {
        let view = MetalImageView()
        return view
    }()
    
    public override init(frame: CGRect, player: VCPlayer? = nil) {
        super.init(frame: frame, player: player)
        addSubview(renderView)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        renderView.frame = fitRect()
    }
    
    open override func draw(compositionTime: CMTime, images: [String : CIImage], blackImage: CIImage, renderSize: CGSize, renderScale: CGFloat) -> CIImage? {
        guard let ciImage = super.draw(compositionTime: compositionTime, images: images, blackImage: blackImage, renderSize: renderSize, renderScale: renderScale) else {
            return nil
        }
        renderView.image = ciImage
        renderView.redraw()
        return nil
    }
    
}

open class VCSampleBufferDisplayPlayerContainerView: VCCustomRenderView {
    
    lazy var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        layer.isOpaque = true
        return layer
    }()
    
    lazy var context: CIContext = {
        var context: CIContext
        if #available(iOS 13.0, *), let queue = MetalDevice.share.commandQueue {
            context = CIContext(mtlCommandQueue: queue)
        } else if let device = MetalDevice.share.device {
            context = CIContext(mtlDevice: device)
        } else {
            context = CIContext.share
        }
        return context
    }()
    
    var buffer: CVPixelBuffer?
    
    public override init(frame: CGRect, player: VCPlayer? = nil) {
        super.init(frame: frame, player: player)
        layer.addSublayer(sampleBufferDisplayLayer)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        sampleBufferDisplayLayer.frame = fitRect()
        if let _player = self.player {
            let size = _player.videoDescription.renderSize.scaling(_player.videoDescription.renderScale)
            CVPixelBufferCreate(nil, Int(size.width), Int(size.height),
                                kCVPixelFormatType_32BGRA,
                                [kCVPixelBufferIOSurfacePropertiesKey:[:]] as CFDictionary,
                                &buffer)
        }
    }
    
    open override func draw(compositionTime: CMTime, images: [String : CIImage], blackImage: CIImage, renderSize: CGSize, renderScale: CGFloat) -> CIImage? {
        guard let ciImage = super.draw(compositionTime: compositionTime, images: images, blackImage: blackImage, renderSize: renderSize, renderScale: renderScale) else {
            return nil
        }
        guard let buffer = self.buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0));
        context.render(ciImage, to: buffer, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0));
        var samplfeBuffer: CMSampleBuffer?
        var des: CMVideoFormatDescription?
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = compositionTime
        info.duration = CMTime(seconds: 1.0 / (self.player?.videoDescription.fps ?? 24.0), preferredTimescale: 600)
        info.decodeTimeStamp = compositionTime

        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
                                                     imageBuffer: buffer,
                                                     formatDescriptionOut: &des)
        if let des = des {
            CMSampleBufferCreateReadyWithImageBuffer(allocator: nil,
                                                     imageBuffer: buffer,
                                                     formatDescription: des,
                                                     sampleTiming: &info,
                                                     sampleBufferOut: &samplfeBuffer)
        }
        if let samplfeBuffer = samplfeBuffer {
            sampleBufferDisplayLayer.enqueue(samplfeBuffer)
        }
        return nil
    }
    
}
