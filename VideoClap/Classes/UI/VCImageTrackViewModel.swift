//
//  VCImageTrackViewModel.swift
//  VideoClap
//
//  Created by lai001 on 2020/12/25.
//

import UIKit
import AVFoundation

public class VCImageTrackViewModel: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, VCImageTrackViewLayoutDelegate {
    
    public let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    
    public let layout: VCImageTrackViewLayout = {
        let layout = VCImageTrackViewLayout()
        return layout
    }()
    
    public lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isDirectionalLockEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.isUserInteractionEnabled = false
        return collectionView
    }()
    
    public lazy var timeLabel: UIButton = {
        let view = UIButton()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        view.titleLabel?.font = UIFont.systemFont(ofSize: 8, weight: .regular)
        view.contentEdgeInsets = UIEdgeInsets(top: 1, left: 5, bottom: 1, right: 5)
        view.setTitleColor(.white, for: .normal)
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 7
        return view
    }()
    
    public var timeControl: VCTimeControl?
    
    public var displayRect: CGRect?
    
    public var zIndex: Int = 0
    
    public var isSelected: Bool = false
    
    public var cutoff: CMTime = CMTime(value: 0, timescale: 600)
    
    public var maskLayer: CAShapeLayer = CAShapeLayer()
    
    public var path: UIBezierPath = UIBezierPath()
    
    public var cellSize: CGSize = .zero {
        didSet {
            cellConfig?.cellSizeUpdate(newCellSize: cellSize)
        }
    }
    
    public var isStopLoadThumbnail: Bool = false
    
    public var datasourceCount: Int = 0
    
    public var isEnable: Bool = true
    
    internal lazy var reuseIdentifierGroup: [String] = {
        var group: [String] = []
        group.append("VCImageCell")
        let width: CGFloat = 50
        for index in 0..<Int(ceil(UIScreen.main.bounds.width / width)) {
            group.append("VCImageCell\(index)")
        }
        return group
    }()
    
    public var cellConfig: CellConfig? {
        didSet {
            cellConfig?.cellSizeUpdate(newCellSize: cellSize)
            updateTimeLabel()
        }
    }
    
    public var timeLabelText: String? {
        if let seconds = cellConfig?.duration()?.seconds,
           let text = formatter.string(from: NSNumber(value: seconds)) {
            return text + "s"
        }
        return nil
    }
    
    public override init() {
        super.init()
        if isEnable {
            layout.delegate = self
        }
        for reuseIdentifier in reuseIdentifierGroup {
            collectionView.register(VCImageCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        }
        collectionView.addSubview(timeLabel)
        timeLabel.frame.origin = CGPoint(x: 6, y: 6)
    }
    
    public func expectWidth() -> CGFloat? {
        guard let cellConfig = self.cellConfig else { return nil }
        guard cellSize.width.isZero == false else { return nil }
        guard let timeControl = timeControl else { return nil }
        guard let duration = cellConfig.duration() else { return nil }
        let totalWidth: CGFloat = CGFloat(duration.value) * timeControl.widthPerTimeVale
        return totalWidth
    }
    
    public func invalidateLayout(displayRect: CGRect) {
        collectionView.frame.size = self.frame().size
        self.displayRect = displayRect
        layout.invalidateLayout()
    }
    
    public func reloadData() {
        guard cellSize.width.isZero == false else { return }
        guard let totalWidth: CGFloat = self.expectWidth() else { return }
        updateTimeLabel()
        datasourceCount = Int(ceil(totalWidth / cellSize.width))
        collectionView.reloadData()
    }
    
    public func reloadData(displayRect: CGRect) {
        invalidateLayout(displayRect: displayRect)
        reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datasourceCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let index = indexPath.item % reuseIdentifierGroup.count
        let reuseIdentifier = reuseIdentifierGroup[index]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! VCImageCell
        cell.backgroundColor = collectionView.backgroundColor
        cell.contentView.backgroundColor = collectionView.backgroundColor
        cell.imageView.backgroundColor = collectionView.backgroundColor
        if cell.imageView.image == nil {
            cell.imageView.image = cellConfig?.placeholderImage()
        }
        if let cellConfig = self.cellConfig, let timeControl = self.timeControl, isStopLoadThumbnail == false {
            cellConfig.updateCell(cell: cell, index: indexPath.item, timeControl: timeControl)
        }
        return cell
    }
    
    public func frame() -> CGRect {
        let x: CGFloat = (timeControl?.widthPerTimeVale ?? 0) * CGFloat(cellConfig?.targetTimeRange()?.start.value ?? 0)
        let y: CGFloat = 0
        let size = CGSize(width: expectWidth() ?? .zero, height: cellSize.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
    
    @discardableResult
    public func updateTimeLabel() -> Bool {
        if let text = timeLabelText {
            timeLabel.setTitle(text, for: .normal)
            timeLabel.sizeToFit()
            return true
        } else {
            return false
        }
    }
    
}
