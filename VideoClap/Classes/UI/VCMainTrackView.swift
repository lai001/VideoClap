//
//  VCMainTrackView.swift
//  VideoClap
//
//  Created by lai001 on 2021/3/1.
//

import Foundation
import SnapKit

public protocol VCMainTrackViewDelegate: NSObject {
    func dataSource() -> [VCImageTrackViewModel]
    func didSelectItemAt(_ model: VCImageTrackViewModel, index: Int)
    func preReloadModel(_ model: VCImageTrackViewModel, visibleRect: CGRect)
    func postReloadModel(_ model: VCImageTrackViewModel, visibleRect: CGRect)
}

public class VCMainTrackViewLayout: UICollectionViewLayout {
    
    public weak var delegate: VCMainTrackViewDelegate?
    
    var cacheLayoutAttributesForElements: [UICollectionViewLayoutAttributes] = []
    
    public override func prepare() {
        super.prepare()
        _invalidateLayout()
    }
    
    public func layoutAttributesForElements(at point: CGPoint) -> [UICollectionViewLayoutAttributes]? {
        return cacheLayoutAttributesForElements.filter({ $0.frame.contains(point) })
    }
    
    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cacheLayoutAttributesForElements[indexPath.item]
    }
    
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cacheLayoutAttributesForElements
    }
    
    private func _invalidateLayout() {
        cacheLayoutAttributesForElements = []
        if let delegate = self.delegate {
            for (index, model) in delegate.dataSource().enumerated() {
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
                attributes.frame = model.frame()
                attributes.zIndex = model.zIndex
                cacheLayoutAttributesForElements.append(attributes)
            }
        }
    }
    
    public override func invalidateLayout() {
        self._invalidateLayout()
        super.invalidateLayout()
    }
    
    override public var collectionViewContentSize: CGSize {
        guard let col = collectionView else { return .zero }
        return col.bounds.size
    }
    
}

public struct Quadrilateral {
    let point0: CGPoint
    let point1: CGPoint
    let point2: CGPoint
    let point3: CGPoint
}

open class VCMainTrackView: UIView, UICollectionViewDataSource, UICollectionViewDelegate, VCMainTrackViewDelegate {
    
    public weak var viewDelegate: VCMainTrackViewDelegate?
    
    public lazy var layout: VCMainTrackViewLayout = {
        let layout = VCMainTrackViewLayout()
        layout.delegate = self
        return layout
    }()
    
    public lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.clipsToBounds = false
        return collectionView
    }()
    
    public var timeControl: VCTimeControl?
    
    public override var backgroundColor: UIColor? {
        didSet {
            collectionView.backgroundColor = backgroundColor
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(collectionView)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = self.bounds
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.numberOfItems()
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = collectionView.backgroundColor
        cell.contentView.backgroundColor = collectionView.backgroundColor
        let model = getModel(index: indexPath.item)
        cell.contentView.addSubview(model.collectionView)
        model.collectionView.backgroundColor = collectionView.backgroundColor
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectItemAt(getModel(index: indexPath.item), index: indexPath.item)
    }
    
    public func reloadData(in rect: CGRect) {
        let layoutAttributesForElements = layout.layoutAttributesForElements(in: rect) ?? []
        for layoutAttributes in layoutAttributesForElements {
            if layoutAttributes.frame.intersects(rect) {
                let model = self.getModel(index: layoutAttributes.indexPath.item)
                preReloadModel(model, visibleRect: rect)
                if rect.minX > layoutAttributes.frame.minX {
                    model.timeLabel.frame.origin.x = rect.minX - layoutAttributes.frame.minX + 6
                } else {
                    model.timeLabel.frame.origin.x = 6
                }
                model.collectionView.frame.size = model.frame().size
                
                model.reloadData(displayRect: rect)
                
                if let widthPerTimeVale = timeControl?.widthPerTimeVale, model.cutoff.value > 0 {
                    let width = widthPerTimeVale * CGFloat(model.cutoff.value)
                    let leftQuadrilateral = Quadrilateral(point0: CGPoint(x: 0, y: 0),
                                                          point1: CGPoint(x: model.collectionView.bounds.maxX, y: 0),
                                                          point2: CGPoint(x: model.collectionView.bounds.maxX - width, y: model.collectionView.bounds.maxY),
                                                          point3: CGPoint(x: 0, y: model.collectionView.bounds.maxY))
                    model.path.removeAllPoints()
                    model.path.move(to: leftQuadrilateral.point0)
                    model.path.addLine(to: leftQuadrilateral.point1)
                    model.path.addLine(to: leftQuadrilateral.point2)
                    model.path.addLine(to: leftQuadrilateral.point3)
                    model.path.close()
                    
                    model.maskLayer.frame = model.collectionView.bounds
                    model.maskLayer.path = model.path.cgPath
                    
                    model.collectionView.layer.mask = model.maskLayer
                    model.collectionView.layer.masksToBounds = true
                }
                
                postReloadModel(model, visibleRect: rect)
            }
        }
    }
    
    public func totalWidth() -> CGFloat {
        let width: CGFloat = dataSource().reduce(CGFloat.zero) { (result, model) -> CGFloat in
            return result + (model.expectWidth() ?? 0)
        }
        return width
    }
    
    public func dataSource() -> [VCImageTrackViewModel] {
        return viewDelegate?.dataSource() ?? []
    }
    
    public func numberOfItems() -> Int {
        return viewDelegate?.dataSource().count ?? 0
    }
    
    public func getModel(index: Int) -> VCImageTrackViewModel {
        return dataSource()[index]
    }
    
    public func didSelectItemAt(_ model: VCImageTrackViewModel, index: Int) {
        viewDelegate?.didSelectItemAt(model, index: index)
    }
    
    public func preReloadModel(_ model: VCImageTrackViewModel, visibleRect: CGRect) {
        viewDelegate?.preReloadModel(model, visibleRect: visibleRect)
    }
    
    public func postReloadModel(_ model: VCImageTrackViewModel, visibleRect: CGRect) {
        viewDelegate?.postReloadModel(model, visibleRect: visibleRect)
    }
    
}
