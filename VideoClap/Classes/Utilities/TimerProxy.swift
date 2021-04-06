//
//  TimerProxy.swift
//  VideoClap
//
//  Created by lai001 on 2021/3/24.
//

import Foundation

public class TimerProxy: NSObject {
    
    public private(set) var timer: Timer?
    private var block: ((Timer) -> Void)?
    private var timeInterval: TimeInterval = .zero
    private var repeats: Bool = true
    
    public init(withTimeInterval timeInterval: TimeInterval, repeats: Bool, block: ((Timer) -> Void)?) {
        super.init()
        self.block = block
        self.repeats = repeats
        self.timeInterval = timeInterval
        setupTimer()
    }
    
    deinit {
        invalidate()
    }

    private func setupTimer() {
        if #available(iOS 10.0, *) {
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: repeats, block: { [weak self] (timer) in
                guard let self = self else { return }
                self.timerTick(timer)
            })
        } else {
            timer = Timer(timeInterval: timeInterval, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: repeats)
        }
    }
    
    @objc private func timerTick(_ timer: Timer) {
        block?(timer)
    }

    public func invalidate() {
        timer?.invalidate()
        timer = nil
    }
    
    public func add(to runLoop: RunLoop = .current, forMode mode: RunLoop.Mode = RunLoop.Mode.default) {
        guard let _timer = self.timer else {
            return
        }
        runLoop.add(_timer, forMode: mode)
    }
    
}
