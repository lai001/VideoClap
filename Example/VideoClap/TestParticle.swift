//
//  TestParticle.swift
//  VideoClap_Example
//
//  Created by lai001 on 2021/4/3.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import SnapKit
import VideoClap
import CoreMedia

class TestParticle: UIViewController {
    
    lazy var particleSystem: VCParticleSystem = {
        let system = VCParticleSystem()
        return system
    }()
    
    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = .black
        return view
    }()
    
    lazy var dotImage: UIImage? = {
        return nil 
        return UIImage(contentsOfFile: resourceURL(filename: "dot.png")?.path ?? "")
    }()
    
    lazy var startImage: UIImage = {
        let s = NSAttributedString(string: "🌟", attributes: [.font : UIFont.systemFont(ofSize: 40, weight: .medium)])
        let renderer = VCGraphicsRenderer(s.size())
        return renderer.image { (context) in
            s.draw(at: .zero)
        }.unsafelyUnwrapped
    }()
    
    var timer: TimerProxy?
    
    lazy var emitter: VCParticleEmitter = {
        let emitter = VCParticleEmitter.make(timeRange: CMTimeRange(start: 0, duration: 20.0),
                                             emitRate: 15,
                                             particleLifetimeRange: 0.0...5.0,
                                             xAccelerationRange: -250.0...250.0,
                                             yAccelerationRange: -250.0...250.0,
                                             startColor: .red,
                                             endColor: UIColor.orange.withAlphaComponent(0.0),
                                             center: CGPoint(x: renderer.rendererRect.midX, y: renderer.rendererRect.midY))
        return emitter
    }()
    
    lazy var renderer: VCParticleEmitterRenderer = {
        let renderer = VCParticleEmitterRenderer()
        renderer.rendererRect.size = CGSize(width: 414, height: 414)
        return renderer
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        renderer.emitter = emitter
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.size.equalTo(renderer.rendererRect.size)
            make.center.equalToSuperview()
        }
        
        var time = CMTime(seconds: 0.0)
        let interval = CMTime(seconds: 1.0 / 24.0)
        let timer = TimerProxy(withTimeInterval: interval.seconds, repeats: true) { [weak self] (timer) in
            guard let self = self else { return }
            self.emitter.time = time
            self.emitter.update()
            self.imageView.image = self.renderer.render(image: self.dotImage ?? self.startImage)
            time = CMTime(seconds: (time + interval).seconds.truncatingRemainder(dividingBy: 20.0))
        }
        self.timer = timer
        timer.add()
    }
    
}
