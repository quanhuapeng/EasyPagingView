//
//  EasyContainerScrollView.swift
//  ScrollViewDemo
//
//  Created by quanhua on 2020/12/20.
//

import UIKit

let kIsDragging = "kIsDragging"
let kContentSize = "contentSize"
let kContentOffset = "contentOffset"
let kFrame = "frame"
let kBounds = "bounds"
let cellIdentifier = "EasyPagingViewPageCell"

// MARK: - KVO
let PageListViewKVOContext = UnsafeMutableRawPointer(bitPattern: 1)
let ContentViewKVOContext = UnsafeMutableRawPointer(bitPattern: 2)
let NormalViewKVOContext = UnsafeMutableRawPointer(bitPattern: 3)

public protocol EasyPagingListViewDelegate: NSObjectProtocol {
    var pageView: UIView { get }
    var pageListView: UICollectionView { get }
    func pageListViewWillAppear()
    func pageListViewDidAppear()
    func pageListViewDidDisappear()
}

public extension EasyPagingListViewDelegate {
    
    func pageListViewWillAppear() {
        
    }
    
    func pageListViewDidAppear() {
        
    }
    
    func pageListViewDidDisappear() {
        
    }
}

public protocol EasyPagingViewDataSource: NSObjectProtocol {

    func numberOfLists(in easyPagingView: EasyPagingView) -> Int
    func easyPagingView(_ easyPagingView: EasyPagingView, pageForItemAt index: Int) -> EasyPagingListViewDelegate
}

public protocol EasyPagingViewDelegate: NSObjectProtocol {
    func segmentViewWillBeginPaningToTop() // segmentView 即将往上拖动
    func segmentViewDidPaningToTop()       // segmentView 已被拖动到顶部
    func segmentViewWillBeginPaningToBottom() // segmentView 即将往下拖动
    func segmentViewDidPaningToBottom() // segmentView 已被拖动到底部
}

public extension EasyPagingViewDelegate {
    func segmentViewWillBeginPaningToTop() { }
    func segmentViewDidPaningToTop() {}
    func segmentViewWillBeginPaningToBottom() {}
    func segmentViewDidPaningToBottom() {}
}

open class EasyPagingView: UIScrollView {

    private enum ScrollingDirection {
        case up
        case down
    }

    /// 顶部固定位置
    public var segmentViewInsetTop: CGFloat = 0
    /// segmentView 是否固定在底部
    public var isSegmentViewOnBottomEnable: Bool = true
    /// 默认的列表索引
    public var defaultSelectedIndex: Int = 0

    public var headerView: UIView?
    public var segmentView: UIView!
    public var pageCollectionView: UICollectionView!

    var pageDict = [Int : EasyPagingListViewDelegate]()
    var pageListViewOffsetDict = [Int: CGFloat]()
    var easyPagingViewOffsetDict = [Int: CGFloat]()
    var pageCollectionViewOriginY: CGFloat = 0

    /// 当 segmentView 未到达最高点时切换列表
    var isSwitchToNewPageWhenSegmentViewNotOnTop: Bool = false
    var isPaningEndJustNow: Bool = false
    var switchToNewPageWhenSegmentViewNotInTopEasyPagingViewOffset: CGFloat = 0
    var lastOffsetY: CGFloat = 0
    var isScrollingDown: Bool = false
    
    // segmentView.origin.y
    var segmentViewOriginY: CGFloat = 0 // segmentView 的 origin.y（相对于 self.contentOffset.y)
    var segmentViewScrollUpAbleOffsetY: CGFloat = 0 // 当 self.contentOffset.y 大于此值时，segmentView 开始向上滚动

    // 拖动
    var pageCollectionViewOffsetY: CGFloat = 0
    var segmentViewDragingBeginOriginY: CGFloat = 0

    /// 正在拖动 segmentView
    var isSegmentViewPaning: Bool = false
    var panGesture: UIPanGestureRecognizer?
    var pagePanGesture: UIPanGestureRecognizer?

    var currentIndex: Int = 0
    var currentPageListViewOffsetY: CGFloat = 0
    var currentSubviewOriginY: CGFloat = 0.0

    var subviewsInLayoutOrder = [UIView]()

    public var contentView: UIView!

    public override init(frame: CGRect) {
        super.init(frame: frame)

        commonInitForEasyContainerScrollview()
    }

    public weak var dataSource: EasyPagingViewDataSource? {
        didSet {
            UIScrollView.swizzleIsDragging
        }
    }
    
    public weak var easyDelegate: EasyPagingViewDelegate?

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.removeObserver(self, forKeyPath: kContentOffset, context: ContentViewKVOContext)
        
        if hadHeaderView {
            for (_, page) in pageDict {
                page.pageListView.removeObserver(self, forKeyPath: kContentSize, context: PageListViewKVOContext)
                page.pageListView.removeObserver(self, forKeyPath: kContentOffset, context: PageListViewKVOContext)
            }
        }
        
        for subview in subviewsInLayoutOrder {
            if let scrollView = subview as? UIScrollView {
                if scrollView !== pageCollectionView {
                    scrollView.isScrollEnabled = false
                    scrollView.removeObserver(self, forKeyPath: kContentSize)
                }
            } else {
                subview.removeObserver(self, forKeyPath: kFrame)
                subview.removeObserver(self, forKeyPath: kBounds)
            }
        }
    }

    private func commonInitForEasyContainerScrollview() {
        self.delegate = self
        contentView = EasyContainerScrollViewContentView()
        self.addSubview(contentView)

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        pageCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        pageCollectionView.dataSource = self
        pageCollectionView.delegate = self
        pageCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        pageCollectionView.isPagingEnabled = true
        pageCollectionView.bounces = false
        pageCollectionView.showsHorizontalScrollIndicator = false
        pageCollectionView.contentInsetAdjustmentBehavior = .never

        self.addObserver(self, forKeyPath: kContentOffset, options: .old, context: ContentViewKVOContext)

        if isSegmentViewOnBottomEnable {
            pagePanGesture = UIPanGestureRecognizer(target: self, action: #selector(segmentViewPanGesture(_:)))
            pagePanGesture?.delegate = self
        }
    }

    public func reloadData() {
        guard segmentView != nil else { fatalError("segmentView is nil") }

        if let headerView = headerView, headerView.superview == nil {
            contentView.addSubview(headerView)
        }

        if let segmentView = segmentView, segmentView.superview == nil {
            panGesture = UIPanGestureRecognizer(target: self, action: #selector(segmentViewPanGesture(_:)))
            segmentView.addGestureRecognizer(panGesture!)
            contentView.addSubview(segmentView)
        }

        if pageCollectionView.superview == nil {
            let segmentViewHeight = segmentView.frame.height
            let pageCollectionViewHeight = self.bounds.height - segmentViewHeight - segmentViewInsetTop
            pageCollectionView.frame = CGRect(x: 0, y: segmentViewHeight + segmentViewInsetTop, width: UIScreen.main.bounds.width, height: pageCollectionViewHeight)
            contentView.addSubview(pageCollectionView)
        }
        pageCollectionView.reloadData()
        
        contentView.bringSubviewToFront(segmentView)
        
        if !hadHeaderView {
            self.isScrollEnabled = false
        }
    }
    
    // 外部调用，主动切换到第 index 个列表
    public func scrollToPageViewAt(_ index: Int) {
        horizontalScrollDidEnd(at: index)
    }
    
    private var hadHeaderView: Bool {
        return (headerView != nil) && (segmentView != nil)
    }

    // MARK: - Adding and removing subviews

    func didAddSubviewToContainer(_ subview: UIView) {

        let index = subviewsInLayoutOrder.firstIndex { subview === $0 }
        if let index = index {
            subviewsInLayoutOrder.remove(at: index)
            subviewsInLayoutOrder.append(subview)
            self.setNeedsLayout()
            return
        }

        subviewsInLayoutOrder.append(subview)

        if let scrollView = subview as? UIScrollView {
            if scrollView !== pageCollectionView {
                scrollView.isScrollEnabled = false
                scrollView.addObserver(self, forKeyPath: kContentSize, options: .old, context: ContentViewKVOContext)
            }
        } else {
            subview.addObserver(self, forKeyPath: kFrame, options: .old, context: NormalViewKVOContext)
            subview.addObserver(self, forKeyPath: kBounds, options: .old, context: NormalViewKVOContext)
        }

        self.setNeedsLayout()
    }

    func willRemoveSubviewFromContainer(_ subview: UIView) {
        if let scrollView = subview as? UIScrollView {
            if scrollView !== pageCollectionView {
                scrollView.isScrollEnabled = false
                scrollView.removeObserver(self, forKeyPath: kContentSize, context: PageListViewKVOContext)
                scrollView.removeObserver(self, forKeyPath: kContentOffset, context: PageListViewKVOContext)
            }
        } else {
            subview.removeObserver(self, forKeyPath: kFrame, context: NormalViewKVOContext)
            subview.removeObserver(self, forKeyPath: kBounds, context: NormalViewKVOContext)
        }

        subviewsInLayoutOrder.removeAll(where: { $0 === subview })
        self.setNeedsLayout()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        guard !isSegmentViewPaning else { return }
        currentPageListViewOffsetY = 0
        currentSubviewOriginY = 0.0

        updateContentOffset()
        layoutContentView()
        layoutHeaderView()
        layoutSegmentView()
        layoutPageListView()
        updateContentSize()
    }

    private func updateContentOffset() {
        // 维护 segmentView 不在顶部时，切换列表时的 contentOffset.y
        var switchToNewPageAndScrollDownOffsetY: CGFloat = 0
        if isSwitchToNewPageWhenSegmentViewNotOnTop {
            if isScrollingDown {
                // 向下滚动
                switchToNewPageAndScrollDownOffsetY = self.contentOffset.y - switchToNewPageWhenSegmentViewNotInTopEasyPagingViewOffset
                self.contentOffset.y = switchToNewPageWhenSegmentViewNotInTopEasyPagingViewOffset
            }

            if !isSegmentViewOnTop {
                currentPageListViewOffsetY = pageListViewOffsetDict[currentIndex] ?? 0
                currentPageListViewOffsetY += switchToNewPageAndScrollDownOffsetY
                let contentOffsetY = easyPagingViewOffsetDict[currentIndex] ?? 0
                easyPagingViewOffsetDict[currentIndex] = contentOffsetY + switchToNewPageAndScrollDownOffsetY
                if currentPageListViewOffsetY <= 0 {
                    isSwitchToNewPageWhenSegmentViewNotOnTop = false
                    currentPageListViewOffsetY = 0
                }
            } else {
                isSwitchToNewPageWhenSegmentViewNotOnTop = false
                self.contentOffset.y += (pageListViewOffsetDict[currentIndex] ?? 0)
            }
            switchToNewPageWhenSegmentViewNotInTopEasyPagingViewOffset = self.contentOffset.y
        } else {
            if isPaningEndJustNow {
                currentPageListViewOffsetY = pageListViewOffsetDict[currentIndex] ?? 0
                if isSegmentViewOnTop {
                    isPaningEndJustNow = false
                    for (index, pageOffsetY) in pageListViewOffsetDict {
                        let contentOffsetY = easyPagingViewOffsetDict[index] ?? 0
                        easyPagingViewOffsetDict[index] = max(contentOffsetY, segmentViewOriginY + pageOffsetY)
                    }
                    self.contentOffset.y = max(segmentViewOriginY + currentPageListViewOffsetY, self.contentOffset.y)
                }
            }

            easyPagingViewOffsetDict[currentIndex] = self.contentOffset.y
        }
    }

    // 重新设置 contentView.bounds
    private func layoutContentView() {
        contentView.frame = self.bounds
        contentView.bounds = CGRect(origin: self.contentOffset, size: contentView.bounds.size)
        let segmentViewHeight: CGFloat = segmentView?.frame.height ?? 0
        pageCollectionView.frame.size.height = self.bounds.height - segmentViewHeight - segmentViewInsetTop
    }

    private func layoutHeaderView() {
        // 布局 headerView
        if let headerScrollView = headerView as? UIScrollView {
            var frame = headerScrollView.frame
            var contentOffset = headerScrollView.contentOffset

            if self.contentOffset.y < currentSubviewOriginY {
                contentOffset.y = 0.0
                frame.origin.y = currentSubviewOriginY
            } else {
                contentOffset.y = self.contentOffset.y - currentSubviewOriginY
                frame.origin.y = self.contentOffset.y
            }

            let remainingBoundsHeight = max(self.bounds.maxY, frame.minY)
            let remainingContentHeight = max(headerScrollView.contentSize.height - contentOffset.y, 0.0)
            frame.size.height = min(remainingBoundsHeight, remainingContentHeight)
            frame.size.width = self.contentView.bounds.width

            headerScrollView.frame = frame
            headerScrollView.contentOffset = contentOffset

            currentSubviewOriginY += headerScrollView.contentSize.height + headerScrollView.contentInset.top + headerScrollView.contentInset.bottom

        } else if let headerView = headerView  {
            var frame = headerView.frame
            frame.origin.y = currentSubviewOriginY
            frame.origin.x = 0
            frame.size.width = self.contentView.bounds.width
            headerView.frame = frame
            currentSubviewOriginY += frame.size.height
        }
    }

    private func layoutSegmentView() {
        guard let segmentView = segmentView else { return }

        // 重新布局 segmentView
        var frame = segmentView.frame
        var originY: CGFloat = 0
        segmentViewScrollUpAbleOffsetY = currentSubviewOriginY - (bounds.height - frame.height)
        if (contentOffset.y < segmentViewScrollUpAbleOffsetY) && isSegmentViewOnBottomEnable  {
            originY = contentOffset.y + bounds.height - frame.height
            panGesture?.isEnabled = true
            pagePanGesture?.isEnabled = true
        } else {
            panGesture?.isEnabled = false
            pagePanGesture?.isEnabled = false
            originY = max(currentSubviewOriginY, self.contentOffset.y + segmentViewInsetTop)
        }
        frame.origin.y = max(originY, self.contentOffset.y)
        frame.origin.x = 0
        frame.size.width = self.contentView.bounds.width
        segmentView.frame = frame
        self.segmentViewOriginY = originY
        currentSubviewOriginY += frame.size.height
    }

    private func layoutPageListView() {
        guard let pageCollectionView = self.pageCollectionView else { return }
        // 重新布局 page 列表
        let segmentViewHeight: CGFloat = segmentView?.frame.height ?? 0
        self.pageCollectionViewOriginY = currentSubviewOriginY - segmentViewHeight - segmentViewInsetTop
        var frame = pageCollectionView.frame
        frame.origin.y = max(currentSubviewOriginY, self.contentOffset.y + segmentViewHeight + segmentViewInsetTop)
        frame.origin.x = 0
        frame.size.width = self.contentView.bounds.width
        pageCollectionView.frame = frame
        pageCollectionViewOffsetY = frame.origin.y
        var pageContentHeight: CGFloat = 0
        if let pageListView = pageDict[currentIndex]?.pageListView {
            if isSegmentViewOnTop {
                currentPageListViewOffsetY = self.contentOffset.y - pageCollectionViewOriginY
            }
            pageListView.contentOffset.y = currentPageListViewOffsetY
            pageListViewOffsetDict[currentIndex] = currentPageListViewOffsetY
            pageContentHeight = pageListView.contentSize.height + pageListView.contentInset.top + pageListView.contentInset.bottom
        }
        currentSubviewOriginY += max(pageContentHeight, pageCollectionView.bounds.size.height)
    }

    var isSegmentViewOnTop: Bool {
        return self.contentOffset.y > self.pageCollectionViewOriginY
    }

    // TODO: 切换 page 的 scrollView contentOffset.y
    func horizontalScrollDidEnd(at index: Int) {
        
        guard currentIndex != index else { return }
        
        pageListViewDidAppear(at: index)
        
        guard hadHeaderView else { return }
        
        // segmentView 正在被拖动中
        if isSegmentViewPaning {
            pageListViewOffsetDict[currentIndex] = pageDict[currentIndex]!.pageListView.contentOffset.y
            pageDict[index]?.pageListView.isScrollEnabled = true
        } else {
            // 自然滑动
            let currentContentOffsetY = easyPagingViewOffsetDict[index] ?? 0
            if isSegmentViewOnTop {
                // segmentView 已经达到顶部，直接切换 contentOffsetY
                self.contentOffset.y = max(self.pageCollectionViewOriginY, currentContentOffsetY)
            } else {
    //            self.contentOffset.y = max(contentOffset.y, currentContentOffsetY)
                // 如果 currentContentOffsetY 不为 nil
                // 当向上滚动，整个 ScrollView 向上，直到 contentOffset.y 达到 pageCollectionViewOriginY
                // 当向下滚动，当前page向下，直到 page.contentOffset.y 到达 0.
                // segmentView 未滚动到顶部，需要情况切换 contentOffsetY，在 layoutSubviews() 内切换。
                if currentIndex != index {
                    isSwitchToNewPageWhenSegmentViewNotOnTop = true
                    switchToNewPageWhenSegmentViewNotInTopEasyPagingViewOffset = contentOffset.y
                }
            }
        }
        
        if index != currentIndex, let gesture = pagePanGesture {
            pageDict[currentIndex]?.pageListView.removeGestureRecognizer(gesture)
            pageDict[index]?.pageListView.addGestureRecognizer(gesture)
        }
        
        currentIndex = index
    }
    
    private func updateContentSize() {
        let minimumContentHeight = self.bounds.size.height - (self.contentInset.top + self.contentInset.bottom)
        let initialContentOffset = self.contentOffset
        self.contentSize = CGSize(width: self.bounds.width, height: max(currentSubviewOriginY, minimumContentHeight))

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
                    if oldContentSize != newContentSize && scrollView === pageDict[currentIndex]?.pageListView {
                        
                        self.setNeedsLayout()
                        self.layoutIfNeeded()
                    }
                }
            } else if keyPath == kContentOffset {
                guard let scrollView = pageDict[currentIndex]?.pageListView else { return }

                if isSegmentViewPaning {
                    let offsetY = scrollView.contentOffset.y
                    pageDict[currentIndex]?.pageListView.bounces = (offsetY > 200)
                }
                pageListViewOffsetDict[currentIndex] = scrollView.contentOffset.y
            }
        } else if context == NormalViewKVOContext {
            if keyPath == kFrame || keyPath == kBounds {
                if let subview = object as? UIView {
                    let oldFrame = change?[.oldKey] as! CGRect
                    let newFrame = subview.frame
                    if oldFrame != newFrame {
                        self.setNeedsLayout()
                    }
                }
            }
        } else if context == ContentViewKVOContext {
            if keyPath == kContentOffset {
                if let scrollView = object as? UIScrollView {
                    if scrollView.contentOffset.y <= lastOffsetY {
                        if scrollView.contentOffset.y != lastOffsetY {
                            isScrollingDown = true
                        }
                    } else {
                        isScrollingDown = false
                    }
                    lastOffsetY = scrollView.contentOffset.y
                }
            } else if keyPath == kContentSize {
                let oldContentSize = change?[.oldKey] as! CGSize
                let newContentSize = (object as! UIScrollView).contentSize
                if oldContentSize != newContentSize {
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// MARK: - CollectionView DataSource & DelegateFlowLayout
extension EasyPagingView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return pageCollectionView.bounds.size
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource?.numberOfLists(in: self) ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        var page = pageDict[indexPath.item]
        if page == nil {
            page = dataSource?.easyPagingView(self, pageForItemAt: indexPath.item)
            pageDict[indexPath.item] = page!
            page?.pageView.setNeedsLayout()
            page?.pageView.layoutIfNeeded()

            if hadHeaderView {
                page?.pageListView.isScrollEnabled = false
                page?.pageListView.addObserver(self, forKeyPath: kContentSize, options: .old, context: PageListViewKVOContext)
                page?.pageListView.addObserver(self, forKeyPath: kContentOffset, options: .old, context: PageListViewKVOContext)

            }
        }

        if let pageView = page?.pageView, pageView.superview != cell.contentView {
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            pageView.frame = cell.contentView.bounds
            cell.contentView.addSubview(pageView)
            page?.pageListView.frame = cell.contentView.bounds
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        pageListViewWillAppear(at: indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let pagePanGesture = pagePanGesture {
            pageDict[indexPath.item]?.pageListView.removeGestureRecognizer(pagePanGesture)
        }
        pageListViewDidDisappear(at: indexPath.item)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard self !== scrollView else { return }
        let index = Int(scrollView.contentOffset.x/scrollView.bounds.size.width)
        horizontalScrollDidEnd(at: index)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if self === scrollView {
            if isSegmentViewOnTop {
                pageDict[currentIndex]?.pageListView.isCurrentDragging = true
            } else {
                pageDict[currentIndex]?.pageListView.isCurrentDragging = nil
            }
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === pageCollectionView else { return }
        if scrollView.isDragging || scrollView.isDecelerating {
            return
        }
        
        let index = Int(scrollView.contentOffset.x/scrollView.bounds.size.width)
        horizontalScrollDidEnd(at: index)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView === self {
//            if isSegmentViewOnTop {
//                pageDict[currentIndex]?.pageListView.isCurrentDragging = nil
//            } else {
//                pageDict[currentIndex]?.pageListView.isCurrentDragging = nil
//            }
            pageDict[currentIndex]?.pageListView.isCurrentDragging = nil
        } else {
            if !decelerate {
                let index = Int(scrollView.contentOffset.x/scrollView.bounds.size.width)
                horizontalScrollDidEnd(at: index)
            }
        }
    }
    
    func pageListViewWillAppear(at index: Int) {
        guard let dataSource = dataSource else { return }
        let count = dataSource.numberOfLists(in: self)
        if count <= 0 || index >= count {
            return
        }
        pageDict[index]?.pageListViewWillAppear()
    }
    
    func pageListViewDidAppear(at index: Int) {
        guard let dataSource = dataSource else { return }
        let count = dataSource.numberOfLists(in: self)
        if count <= 0 || index >= count {
            return
        }
        // 生命周期
        pageDict[index]?.pageListViewDidAppear()
    }

    func pageListViewDidDisappear(at index: Int) {
        guard let dataSource = dataSource else { return }
        let count = dataSource.numberOfLists(in: self)
        if count <= 0 || index >= count {
            return
        }
        pageDict[index]?.pageListViewDidDisappear()
    }
}

extension EasyPagingView {
    
    public func segmentViewScrollToTop() {
        guard let segmentView = self.segmentView else { return }
        guard !isSegmentViewPaning && self.contentOffset.y < self.segmentViewScrollUpAbleOffsetY else { return }
        isSegmentViewPaning = true
        self.isScrollEnabled = false
        pageDict[currentIndex]?.pageListView.isScrollEnabled = true
        easyDelegate?.segmentViewWillBeginPaningToTop()
        self.pageCollectionView.frame.origin.y = (segmentView.frame.origin.y + segmentView.frame.height)
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            let segmentViewDragingEndOriginY = self.segmentViewOriginY - self.bounds.height + self.segmentView!.frame.height + self.segmentViewInsetTop
            self.segmentView?.frame.origin.y = segmentViewDragingEndOriginY
            self.pageCollectionView.frame.origin.y = (segmentView.frame.origin.y + segmentView.frame.height)
        } completion: { (success) in
            if success {
                self.pageDict[self.currentIndex]?.pageListView.addGestureRecognizer(self.pagePanGesture!)
                self.easyDelegate?.segmentViewDidPaningToTop()
            }
        }
    }
    
    @objc func segmentViewPanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let segmentView = self.segmentView else { return }

        if gesture.state == .began {
            if !isSegmentViewPaning {
                self.isScrollEnabled = false
                isSegmentViewPaning = true
                pageDict[currentIndex]?.pageListView.isScrollEnabled = true
                easyDelegate?.segmentViewWillBeginPaningToTop()
            } else {
                easyDelegate?.segmentViewWillBeginPaningToBottom()
            }
            segmentViewDragingBeginOriginY = segmentView.frame.origin.y

        } else if gesture.state == .changed {
            let gestureOffsetY = gesture.translation(in: contentView).y
            segmentView.frame.origin.y = max(segmentViewInsetTop, segmentViewDragingBeginOriginY + gestureOffsetY)
            pageCollectionView.frame.origin.y = (segmentView.frame.origin.y + segmentView.frame.height)
        } else if gesture.state == .ended {
            let velocityY = gesture.velocity(in: contentView).y
            let gestureOffsetY = gesture.translation(in: contentView).y
            didEndScrolling(velocityY: velocityY, gestureOffsetY: gestureOffsetY)
        }
    }

    func didEndScrolling(velocityY: CGFloat, gestureOffsetY: CGFloat) {
        let panHeight = (bounds.height - segmentView!.frame.height) / 2
        let shouldScrollToBottom: Bool
        let isPanMovingDown = gestureOffsetY < 0 // 是否向下拖动
        
        if isPanMovingDown {
            let reachMaxPanHeight = -gestureOffsetY > panHeight
            let reachMaxVelocity = velocityY < -300
            shouldScrollToBottom = !(reachMaxPanHeight || reachMaxVelocity)
        } else {
            let reachMaxPanHeight = gestureOffsetY > panHeight
            let reachMaxVelocity = velocityY > 300
            shouldScrollToBottom = reachMaxPanHeight || reachMaxVelocity
        }

        let segmentViewDragingEndOriginY = !shouldScrollToBottom ? segmentViewOriginY - bounds.height + segmentView!.frame.height + segmentViewInsetTop : segmentViewOriginY
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            self.segmentView?.frame.origin.y = segmentViewDragingEndOriginY
            self.pageCollectionView.frame.origin.y = (self.segmentView!.frame.origin.y + self.segmentView!.frame.height)
        } completion: { (success) in
            if success {
                if segmentViewDragingEndOriginY == self.segmentViewOriginY {
                    self.isSegmentViewPaning = false
                    self.pageCollectionView.frame.origin.y = self.pageCollectionViewOffsetY
                    self.pageDict[self.currentIndex]?.pageListView.isScrollEnabled = false
                    self.isScrollEnabled = true

                    for (_, page) in self.pageDict {
                        page.pageListView.isScrollEnabled = false
                    }
                    self.isPaningEndJustNow = true
                    self.pageDict[self.currentIndex]?.pageListView.removeGestureRecognizer(self.pagePanGesture!)
                    self.easyDelegate?.segmentViewDidPaningToBottom()
                } else {
                    self.pageDict[self.currentIndex]?.pageListView.addGestureRecognizer(self.pagePanGesture!)
                    self.easyDelegate?.segmentViewDidPaningToTop()
                }
            }
        }
    }
}

extension EasyPagingView: UIGestureRecognizerDelegate {

    open override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        if gestureRecognizer === pagePanGesture {
            let velocityY = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: contentView).y ?? 0
            let pageScrollViewOffsetY = pageDict[currentIndex]?.pageListView.contentOffset.y ?? 0
            let isScrollingDown = velocityY > 0
            let isReachOnTop = pageScrollViewOffsetY <= 0
            let isPagePanGestureEnable = isScrollingDown && isReachOnTop && isSegmentViewPaning
            return isPagePanGestureEnable
        }
        return true
    }
}

