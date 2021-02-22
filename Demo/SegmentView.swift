//
//  SegmentView.swift
//  Demo
//
//  Created by Quanhua Peng on 2021/2/17.
//

import UIKit

public struct MenuPageConfiguration {
    public var baseLineColor: UIColor = .systemRed
    public var bottomLineColor: UIColor = .gray
    public var needBottomLine: Bool = true
    public var menuBackgroundColor: UIColor = .white
    public var backgroundColor: UIColor = UIColor.white
    public var margin: UIEdgeInsets = UIEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
    public var itemSpacing: CGFloat = 50
    public var menuAndListMargin: CGFloat = 0
    public var menuHeight: CGFloat = 44.0
    public var itemFont = UIFont.systemFont(ofSize: 15)
    public var selectedItemFont = UIFont.boldSystemFont(ofSize: 15)
    public var selectedItemColor = UIColor.black
    public var itemColor = UIColor.gray
    public var badgeFont = UIFont.systemFont(ofSize: 13)
    public var badgeColor = UIColor.systemRed
    
    init(){
        
    }
}

protocol DefaultSegmentedViewDelegate: NSObjectProtocol {
    func segmentedView(_ segmentedView: SegmentView, didSelectItemAt: Int)
}

class SegmentView: UIView {
    
    private var collectionView: UICollectionView!
    private var collectionLayout: UICollectionViewFlowLayout!
    private var scrollBar: UIView!
    private var bottomLine: UIView!
    var titleList: [String]
    private var titleLabelList = [UILabel]()
    public var currentIndex : Int = 0
    private var configuration : MenuPageConfiguration
    private var lastOffsetRatio: CGFloat = 0
    
    public weak var delegate: DefaultSegmentedViewDelegate?
    
    func reloadData() {
        
        titleLabelList.removeAll()
        
        for index in 0...titleList.count - 1 {

            let title = titleList[index]
            let itemWidthRect : CGRect = (title as NSString).boundingRect(with: CGSize(width: 1000, height: 1000), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font:configuration.selectedItemFont], context: nil)
            
            let titleLabel = UILabel(frame: CGRect(x: 0, y: configuration.margin.top, width: itemWidthRect.width, height: configuration.itemFont.lineHeight))
            titleLabel.text = titleList[index]
            titleLabel.textColor = configuration.itemColor
            titleLabel.font = configuration.itemFont
            titleLabel.textAlignment = .center
            titleLabel.layer.masksToBounds = false
            
            titleLabelList.append(titleLabel)
        }
        
        if let firstTitleView = titleLabelList.first {
            if configuration.needBottomLine {
                bottomLine = UIView(frame: CGRect(x: 0, y: frame.height - 0.5, width: frame.width, height: 0.5))
                bottomLine.backgroundColor = configuration.bottomLineColor
                bottomLine.isHidden = false
                addSubview(bottomLine)
            }
            
            let scrollBarOriginY = configuration.margin.top + configuration.itemFont.lineHeight + 10
            scrollBar.frame = CGRect(x: 0, y: scrollBarOriginY, width: firstTitleView.frame.width, height: 3)
            firstTitleView.textColor = configuration.selectedItemColor
            firstTitleView.font = configuration.selectedItemFont
        }
        
        collectionView.reloadData()
    }
    
    init(frame: CGRect, titleList: [String] = [], configuration: MenuPageConfiguration = MenuPageConfiguration()) {
        self.configuration = configuration
        self.titleList = titleList
        super.init(frame: frame)
        
        setupSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
    }
    
    deinit {
        pageCollectionView?.removeObserver(self, forKeyPath: "contentOffset")
    }
    
    public var pageCollectionView: UICollectionView? {
        didSet {
            pageCollectionView?.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        }
    }
    
    func setupSubviews() {
        
        collectionLayout = UICollectionViewFlowLayout()
        collectionLayout.scrollDirection = .horizontal
        collectionLayout.minimumLineSpacing = configuration.itemSpacing
        collectionLayout.minimumInteritemSpacing = configuration.itemSpacing
        collectionView = UICollectionView(frame: bounds, collectionViewLayout: collectionLayout)
        collectionView.isScrollEnabled = true
        addSubview(collectionView!)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "MenuItemCell")
        collectionView.contentInset.left = configuration.margin.left
        collectionView.contentInset.right = configuration.margin.right
        collectionView.backgroundColor = .clear
        
        scrollBar = UIView(frame: .zero)
        scrollBar?.backgroundColor = configuration.baseLineColor
        collectionView.addSubview(scrollBar!)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setOffset(offsetRatio: CGFloat){
        var offsetX: CGFloat = 0
        let index = Int(offsetRatio)
        if index > 0 {
            for i in 0...index - 1{
                offsetX += titleLabelList[i].bounds.width
                offsetX += collectionLayout!.minimumLineSpacing
            }
        }
        offsetX += (titleLabelList[index].bounds.width + collectionLayout!.minimumLineSpacing) * (offsetRatio - CGFloat(index))
        UIView.animate(withDuration: 0.0, animations: {
            var width: CGFloat
            if index < self.titleLabelList.count - 1{
                width = self.titleLabelList[index].frame.width + (self.titleLabelList[index + 1].frame.width - self.titleLabelList[index].frame.width) * (offsetRatio - CGFloat(index))
            } else {
                width = self.titleLabelList[index].frame.width
            }
            
            self.scrollBar!.frame = CGRect(x:offsetX, y:self.scrollBar!.frame.origin.y, width: width, height:self.scrollBar!.frame.height)
            
            var normalIndex = self.currentIndex
            var selectedIndex = self.currentIndex
            let leftScroll = self.lastOffsetRatio < offsetRatio &&  (offsetRatio - CGFloat(index)) > 0.5
            let rightScroll = self.lastOffsetRatio > offsetRatio && (offsetRatio - CGFloat(index)) < 0.5
            
            if leftScroll {
                normalIndex = self.currentIndex
                selectedIndex = self.currentIndex + 1
            }
            
            if rightScroll {
                normalIndex = self.currentIndex + 1
                selectedIndex = self.currentIndex
            }
            
            if leftScroll || rightScroll {
                self.titleLabelList[normalIndex].textColor = self.configuration.itemColor
                self.titleLabelList[normalIndex].font = self.configuration.itemFont
                self.titleLabelList[selectedIndex].textColor = self.configuration.selectedItemColor
                self.titleLabelList[selectedIndex].font = self.configuration.selectedItemFont
                self.collectionView.scrollToItem(at: IndexPath(item: selectedIndex, section: 0), at: .centeredHorizontally, animated: true)
            }
        })

        currentIndex = index
        lastOffsetRatio = offsetRatio
    }
    
    func setIndex(index: Int, animated: Bool = true){
        var offsetX: CGFloat = 0
        if index > 0 {
            for index in 0...index - 1 {
                offsetX += titleLabelList[index].bounds.width
                offsetX += collectionLayout!.minimumLineSpacing
            }
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                
                self.scrollBar!.frame = CGRect(x: offsetX, y: self.scrollBar!.frame.origin.y, width:self.titleLabelList[index].frame.width, height:self.scrollBar!.frame.height)
            })
        } else {
            self.scrollBar!.frame = CGRect(x: offsetX, y: self.scrollBar!.frame.origin.y, width:self.titleLabelList[index].frame.width, height:self.scrollBar!.frame.height)
        }
        
        titleLabelList[currentIndex].textColor = configuration.itemColor
        titleLabelList[currentIndex].font = configuration.itemFont
        titleLabelList[index].textColor = configuration.selectedItemColor
        titleLabelList[index].font = configuration.selectedItemFont
        currentIndex = index
        lastOffsetRatio = CGFloat(index)
        
        self.collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: animated)
        
        pageCollectionView!.scrollToItem(at: IndexPath(item: index, section: 0), at: .left, animated: false)
        delegate?.segmentedView(self, didSelectItemAt: index)
        currentIndex = index
    }
}

extension SegmentView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
 
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titleList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MenuItemCell", for: indexPath)
        if titleLabelList[indexPath.row].superview == nil {
            cell.contentView.addSubview(titleLabelList[indexPath.row])
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = titleLabelList[indexPath.row].bounds.size.width
        let height = bounds.height
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if currentIndex != indexPath.row {
            setIndex(index: indexPath.row)
        }
    }
}

// MARK: - KVO

extension SegmentView {
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "contentOffset" {
            //用户滚动引起的contentOffset变化，才处理。
            if pageCollectionView!.isTracking || pageCollectionView!.isDecelerating {
                if pageCollectionView!.contentOffset.x == 0 {
                    setOffset(offsetRatio: 0)
                } else {
                    let offsetRatio = pageCollectionView!.contentOffset.x / self.frame.width
                    setOffset(offsetRatio: offsetRatio)
                }
            }
        }
    }
}
