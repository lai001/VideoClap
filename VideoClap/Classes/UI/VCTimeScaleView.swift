//
//  VCTimeScaleView.swift
//  VideoClap
//
//  Created by lai001 on 2020/12/22.
//

import UIKit
import SnapKit
import AVFoundation

public protocol VCTimeScaleViewDelegate: NSObject {
    func cellModel(model: VCTimeScaleCellModel, index: Int)
}

public class VCTimeScaleView: UIView {
    
    public weak var delegate: VCTimeScaleViewDelegate?
    
    public let timeControl: VCTimeControl
    
    internal lazy var cellModels: [VCTimeScaleCellModel] = {
        var cells: [VCTimeScaleCellModel] = (0..<10).map { (_) in
            return VCTimeScaleCellModel()
        }
        return cells
    }()
    
    internal lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimumIntegerDigits = 2
        return formatter
    }()
    
    public var datasourceCount = 0
    
    public var cellWidth: CGFloat = 0
    
    public init(frame: CGRect, timeControl: VCTimeControl) {
        self.timeControl = timeControl
        super.init(frame: frame)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func validate() -> Bool {
        if datasourceCount < 0 || cellWidth <= 0 {
            return false
        }
        return true
    }
    
    public func reloadData(in rect: CGRect) {
        guard validate() else {
            return
        }
        frame.size.width = timeControl.maxLength
        guard let attributes = layoutAttributesForElements(in: rect) else {
            return
        }
        
        let diff = attributes.count - cellModels.count
        if diff > 0 {
            cellModels.append(contentsOf: (0..<diff).map({ _ in return VCTimeScaleCellModel() }))
        }

        for (attribute, cell) in zip(attributes, cellModels[0..<attributes.count]) {
            updateCell(cell, attribute: attribute)
            addSubview(cell.keyTimeLabel)
            addSubview(cell.dotLabel)
            delegate?.cellModel(model: cell, index: attribute.indexPath.item)
        }

        for cell in cellModels[attributes.count..<cellModels.count] {
            cell.keyTimeLabel.removeFromSuperview()
            cell.dotLabel.removeFromSuperview()
        }
    }
    
    private func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let upper = max(0, Int(floor(rect.minX / cellWidth)) )
        let low = min(datasourceCount, Int(ceil(rect.maxX / cellWidth)) )
        var attributes: [UICollectionViewLayoutAttributes] = []
        if low <= upper {
            let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
            attr.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: cellWidth, height: self.bounds.height))
            attributes.append(attr)
            return attributes
        }
        let cellSize = CGSize(width: cellWidth, height: self.bounds.height)
        let y: CGFloat = 0
        for index in upper...low {
            let x: CGFloat = CGFloat(index) * cellWidth
            let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
            attr.frame = CGRect(origin: CGPoint(x: x, y: y), size: cellSize)
            attributes.append(attr)
        }
        return attributes
    }
    
    private func updateCell(_ cell: VCTimeScaleCellModel, attribute: UICollectionViewLayoutAttributes) {
        let index = attribute.indexPath.item
        let time = CMTime(value: timeControl.intervalTime.value * Int64(index), timescale: VCTimeControl.timeBase)
        
        if time.value % 600 == 0 {
            cell.keyTimeLabel.text = format(time: time)
        } else {
            let seconds = time.value / 600
            let remaind = time.value - seconds * 600
            cell.keyTimeLabel.text = "\(remaind / 20)f"
        }
        if index == datasourceCount {
            cell.dotLabel.isHidden = true
        } else {
            cell.dotLabel.isHidden = false
        }
        
        cell.dotLabel.sizeToFit()
        cell.keyTimeLabel.sizeToFit()
        cell.dotLabel.center = attribute.frame.center
        cell.keyTimeLabel.center = CGPoint(x: attribute.frame.minX, y: attribute.frame.midY)
    }
    
    private func format(time: CMTime) -> String {
        let minute = formatter.string(from: NSNumber(value: Int(time.seconds) / 60)) ?? "00"
        let second = formatter.string(from: NSNumber(value: Int(time.seconds) % 60)) ?? "00"
        let timeStr = "\(minute):\(second)"
        return timeStr
    }
    
}
