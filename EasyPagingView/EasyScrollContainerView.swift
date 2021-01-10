//
//  EasyScrollContainerView.swift
//  EasyPagingViewDemo
//
//  Created by Quanhua Peng on 2021/1/9.
//  Copyright © 2021 pengquanhua. All rights reserved.
//

// 参考: https://oleb.net/blog/2014/05/scrollviews-inside-scrollviews/

import UIKit

class EasyScrollContainerView: UIScrollView {

    public var contentView: UIView!
    var subviewsInLayoutOrder = [UIView]()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInitForEasyContainerScrollview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInitForEasyContainerScrollview() {
        
        contentView = EasyContainerScrollViewContentView()
        self.addSubview(contentView)
        
        
    }
    
    func didAddSubviewToContainer(_ subview: UIView) {
        
        let index = subviewsInLayoutOrder.firstIndex { subview === $0 }
        if let index = index {
            subviewsInLayoutOrder.remove(at: index)
            subviewsInLayoutOrder.append(subview)
            self.setNeedsLayout()
            return
        }
        
        subviewsInLayoutOrder.append(subview)
        
        if let scrollView = subview as? UIScrollView{
            scrollView.isScrollEnabled = false
            scrollView.addObserver(self, forKeyPath: kContentSize, options: .old, context: PageListViewKVOContext)
            scrollView.addObserver(self, forKeyPath: kContentOffset, options: .old, context: PageListViewKVOContext)
        } else {
            subview.addObserver(self, forKeyPath: kFrame, options: .old, context: NormalViewKVOContext)
            subview.addObserver(self, forKeyPath: kBounds, options: .old, context: NormalViewKVOContext)
        }
        
        self.setNeedsLayout()
        
    }
    
    func willRemoveSubviewFromContainer(_ subview: UIView) {
        if let scrollView = subview as? UIScrollView{
            scrollView.isScrollEnabled = false
            scrollView.removeObserver(self, forKeyPath: kContentSize, context: PageListViewKVOContext)
            scrollView.removeObserver(self, forKeyPath: kContentOffset, context: PageListViewKVOContext)
        } else {
            subview.removeObserver(self, forKeyPath: kFrame, context: NormalViewKVOContext)
            subview.removeObserver(self, forKeyPath: kBounds, context: NormalViewKVOContext)
        }
        
        subviewsInLayoutOrder.removeAll(where: { $0 === subview })
        self.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = self.bounds
        contentView.bounds = CGRect(origin: self.contentOffset, size: contentView.bounds.size)
        
        var yOffsetOfCurrentSubview: CGFloat = 0.0
        
        for index in 0..<subviewsInLayoutOrder.count {
            let subview = subviewsInLayoutOrder[index]
            
            if let scrollView = subview as? UIScrollView {
                var frame = scrollView.frame
                var contentOffset = scrollView.contentOffset
                
                if self.contentOffset.y < yOffsetOfCurrentSubview {
                    contentOffset.y = 0.0
                    frame.origin.y = yOffsetOfCurrentSubview
                } else {
                    contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
                    frame.origin.y = self.contentOffset.y
                }
                
                let remainingBoundsHeight = max(self.bounds.maxY, frame.minY)
                let remainingContentHeight = max(scrollView.contentSize.height - contentOffset.y, 0.0)
                frame.size.height = min(remainingBoundsHeight, remainingContentHeight)
                frame.size.width = self.contentView.bounds.width
                scrollView.frame = frame
                scrollView.contentOffset = contentOffset
                
                yOffsetOfCurrentSubview += scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom
            } else {
                var frame = subview.frame
                frame.origin.y = yOffsetOfCurrentSubview
                frame.origin.x = 0
                frame.size.width = self.contentView.bounds.width
                subview.frame = frame
                yOffsetOfCurrentSubview += frame.size.height
            }
        }
        
        let minimumContentHeight = self.bounds.size.height - (self.contentInset.top + self.contentInset.bottom)
        let initialContentOffset = self.contentOffset
        self.contentSize = CGSize(width: self.bounds.width, height: max(yOffsetOfCurrentSubview, minimumContentHeight))
        
        if initialContentOffset != self.contentOffset {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if context == PageListViewKVOContext {
            
            if keyPath == kContentSize {
                if let scrollView = object as? UIScrollView {
                    let oldContentSize = change?[.oldKey] as! CGSize
                    let newContentSize = scrollView.contentSize
                    if oldContentSize != newContentSize  {
                        self.setNeedsLayout()
                        self.layoutIfNeeded()
                    }
                }
            }
        } else if context == NormalViewKVOContext {
            if keyPath == kFrame || keyPath == kBounds {
                if let subview = object as? UIView {
                    let oldFrame = change?[.oldKey] as! CGRect
                    let newFrame = subview.frame
                    if oldFrame != newFrame {
                        self.setNeedsLayout()
                        self.layoutIfNeeded()
                    }
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
