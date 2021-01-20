//
//  EasyContainerScrollView.swift
//  ScrollViewDemo
//
//  Created by quanhua on 2020/12/20.
//

import UIKit

let kContentSize = "contentSize"
let kContentOffset = "contentOffset"
let kFrame = "frame"
let kBounds = "bounds"
let cellIdentifier = "EasyPagingViewPageCell"

// MARK: - KVO
let PageListViewKVOContext = UnsafeMutableRawPointer(bitPattern: 1)
let ContentViewKVOContext = UnsafeMutableRawPointer(bitPattern: 2)
let NormalViewKVOContext = UnsafeMutableRawPointer(bitPattern: 3)

public protocol EasyPagingViewDelegate: NSObjectProtocol {
    var pageView: UIView { get }
    var pageListView: UICollectionView { get }
}

public protocol EasyPagingViewDataSource: NSObjectProtocol {

    func numberOfLists(in easyPagingView: EasyPagingView) -> Int
    func easyPagingView(_ easyPagingView: EasyPagingView, pageForItemAt index: Int) -> EasyPagingViewDelegate
}

open class EasyPagingView: UIScrollView {

    private enum ScrollingDirection {
        case up
        case down
    }

    /// 顶部固定位置
    public var pinInsetTop: CGFloat = 0
    /// pinView 是否固定在底部
    public var isPinOnBottomEnable: Bool = true
    /// 默认的列表索引
    public var defaultSelectedIndex: Int = 0

    public var pageHeaderView: UIView?
    public var pagePinView: UIView?
    public var pageCollectionView: UICollectionView!

    var pageDict = [Int : EasyPagingViewDelegate]()
    var pageCurrentOffsetDict = [Int: CGFloat]()
    var contentOffsetDict = [Int: CGFloat]()
    var pageCollectionViewOriginY: CGFloat = 0

    /// 当 pinView 未到达最高点时切换列表
    var isSwitchToNewPageWhenPinViewNotOnTop: Bool = false
    var isPaningEndJustNow: Bool = false
    var switchToNewPageWhenPinViewNotInTopContentOffset: CGFloat = 0
    var lastOffsetY: CGFloat = 0
    var isScrollingDown: Bool = false
    
    // pinView.origin.y
    var pinViewOffsetY: CGFloat = 0

    // 拖动
    var pageCollectionViewOffsetY: CGFloat = 0
    var pinViewDragingBeginOriginY: CGFloat = 0

    /// 正在拖动 pinView
    var isPinViewPaning: Bool = false
    var panGesture: UIPanGestureRecognizer?
    var pagePanGesture: UIPanGestureRecognizer?

    var currentIndex: Int = 0
    var currentPageListViewOffsetY: CGFloat = 0
    var currentSubviewOffsetY: CGFloat = 0.0

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

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.removeObserver(self, forKeyPath: kContentOffset, context: ContentViewKVOContext)

        for (_, page) in pageDict {
            page.pageListView.removeObserver(self, forKeyPath: kContentSize, context: PageListViewKVOContext)
            page.pageListView.removeObserver(self, forKeyPath: kContentOffset, context: PageListViewKVOContext)
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

        if isPinOnBottomEnable {
            pagePanGesture = UIPanGestureRecognizer(target: self, action: #selector(pinViewPanGesture(_:)))
            pagePanGesture?.delegate = self
        }
    }

    public func reloadData() {

        if let headerView = pageHeaderView {
            contentView.addSubview(headerView)
        }

        if let pinView = pagePinView {
            panGesture = UIPanGestureRecognizer(target: self, action: #selector(pinViewPanGesture(_:)))
            pinView.addGestureRecognizer(panGesture!)
            contentView.addSubview(pinView)
        }

        contentView.addSubview(pageCollectionView)
        pageCollectionView.reloadData()
        if let pinView = pagePinView {
            contentView.bringSubviewToFront(pinView)
        }
        
        if !hadHeaderView {
            self.isScrollEnabled = false
        }
    }
    
    private var hadHeaderView: Bool {
        return (pageHeaderView != nil) && (pagePinView != nil)
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
            }
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

    open override func layoutSubviews() {
        super.layoutSubviews()
        guard !isPinViewPaning else { return }
        currentPageListViewOffsetY = 0
        currentSubviewOffsetY = 0.0

        updateContentOffset()
        layoutContentView()
        layoutHeaderView()
        layoutPinView()
        layoutPageListView()
        updateContentSize()
    }

    private func updateContentOffset() {
        // 维护 PinView 不在顶部时，切换列表时的 contentOffset.y
        var switchToNewPageAndScrollDownOffsetY: CGFloat = 0
        if isSwitchToNewPageWhenPinViewNotOnTop {
            if isScrollingDown {
                // 向下滚动
                switchToNewPageAndScrollDownOffsetY = self.contentOffset.y - switchToNewPageWhenPinViewNotInTopContentOffset
                self.contentOffset.y = switchToNewPageWhenPinViewNotInTopContentOffset
            }

            if !isPinViewOnTop {
                currentPageListViewOffsetY = pageCurrentOffsetDict[currentIndex] ?? 0
                currentPageListViewOffsetY += switchToNewPageAndScrollDownOffsetY
                let contentOffsetY = contentOffsetDict[currentIndex] ?? 0
                contentOffsetDict[currentIndex] = contentOffsetY + switchToNewPageAndScrollDownOffsetY
                if currentPageListViewOffsetY <= 0 {
                    isSwitchToNewPageWhenPinViewNotOnTop = false
                    currentPageListViewOffsetY = 0
                }
            } else {
                isSwitchToNewPageWhenPinViewNotOnTop = false
                self.contentOffset.y += (pageCurrentOffsetDict[currentIndex] ?? 0)
            }
            switchToNewPageWhenPinViewNotInTopContentOffset = self.contentOffset.y
        } else {
            if isPaningEndJustNow {
                currentPageListViewOffsetY = pageCurrentOffsetDict[currentIndex] ?? 0
                if isPinViewOnTop {
                    isPaningEndJustNow = false
                    for (index, pageOffsetY) in pageCurrentOffsetDict {
                        let contentOffsetY = contentOffsetDict[index] ?? 0
                        contentOffsetDict[index] = max(contentOffsetY, pinViewOffsetY + pageOffsetY)
                    }
                    self.contentOffset.y = max(pinViewOffsetY + currentPageListViewOffsetY, self.contentOffset.y)
                }
            }

            contentOffsetDict[currentIndex] = self.contentOffset.y
        }
    }

    // 重新设置 contentView.bounds
    private func layoutContentView() {
        contentView.frame = self.bounds
        contentView.bounds = CGRect(origin: self.contentOffset, size: contentView.bounds.size)
        let pagePinViewHeight: CGFloat = pagePinView?.frame.height ?? 0
        pageCollectionView.frame.size.height = self.bounds.height - pagePinViewHeight
    }

    private func layoutHeaderView() {
        // 布局 headerView
        if let headerScrollView = pageHeaderView as? UIScrollView {
            var frame = headerScrollView.frame
            var contentOffset = headerScrollView.contentOffset

            if self.contentOffset.y < currentSubviewOffsetY {
                contentOffset.y = 0.0
                frame.origin.y = currentSubviewOffsetY
            } else {
                contentOffset.y = self.contentOffset.y - currentSubviewOffsetY
                frame.origin.y = self.contentOffset.y
            }

            let remainingBoundsHeight = max(self.bounds.maxY, frame.minY)
            let remainingContentHeight = max(headerScrollView.contentSize.height - contentOffset.y, 0.0)
            frame.size.height = min(remainingBoundsHeight, remainingContentHeight)
            frame.size.width = self.contentView.bounds.width


            headerScrollView.frame = frame
            headerScrollView.contentOffset = contentOffset

            currentSubviewOffsetY += headerScrollView.contentSize.height + headerScrollView.contentInset.top + headerScrollView.contentInset.bottom

        } else if let headerView = pageHeaderView  {
            var frame = headerView.frame
            frame.origin.y = currentSubviewOffsetY
            frame.origin.x = 0
            frame.size.width = self.contentView.bounds.width
            headerView.frame = frame
            currentSubviewOffsetY += frame.size.height
        }
    }

    private func layoutPinView() {
        guard let pinView = pagePinView else { return }

        // 重新布局 pinView
        var frame = pinView.frame
        var originY: CGFloat = 0
        if (contentOffset.y < currentSubviewOffsetY - (bounds.height - frame.height)) && isPinOnBottomEnable  {
            originY = contentOffset.y + bounds.height - frame.height
            panGesture?.isEnabled = true
            pagePanGesture?.isEnabled = true
        } else {
            panGesture?.isEnabled = false
            pagePanGesture?.isEnabled = false
            originY = max(currentSubviewOffsetY, self.contentOffset.y + pinInsetTop)
        }
        frame.origin.y = max(originY, self.contentOffset.y)
        frame.origin.x = 0
        frame.size.width = self.contentView.bounds.width
        pinView.frame = frame
        self.pinViewOffsetY = originY
        currentSubviewOffsetY += frame.size.height
    }

    private func layoutPageListView() {
        guard let pageCollectionView = self.pageCollectionView else { return }
        // 重新布局 page 列表
        let pagePinViewHeight: CGFloat = pagePinView?.frame.height ?? 0
        self.pageCollectionViewOriginY = currentSubviewOffsetY - pagePinViewHeight
        var frame = pageCollectionView.frame
        frame.origin.y = max(currentSubviewOffsetY, self.contentOffset.y + pagePinViewHeight + pinInsetTop)
        frame.origin.x = 0
        frame.size.width = self.contentView.bounds.width
        pageCollectionView.frame = frame
        pageCollectionViewOffsetY = frame.origin.y
        if let pageListView = pageDict[currentIndex]?.pageListView {
            if isPinViewOnTop {
                currentPageListViewOffsetY = self.contentOffset.y - pageCollectionViewOriginY
            }
            pageListView.contentOffset.y = currentPageListViewOffsetY
            pageCurrentOffsetDict[currentIndex] = currentPageListViewOffsetY
            currentSubviewOffsetY += (pageListView.contentSize.height + pageListView.contentInset.top + pageListView.contentInset.bottom)
        }
    }

    var isPinViewOnTop: Bool {
        return self.contentOffset.y > self.pageCollectionViewOriginY
    }

    // TODO: 切换 page 的 scrollView contentOffset.y
    func horizontalScrollDidEnd(at index: Int) {
        guard hadHeaderView else { return }
        
        if isPinViewPaning {
            pageCurrentOffsetDict[currentIndex] = pageDict[currentIndex]!.pageListView.contentOffset.y
            pageDict[index]?.pageListView.isScrollEnabled = true
        } else {
            let currentContentOffsetY = contentOffsetDict[index] ?? 0
            if self.contentOffset.y > self.pageCollectionViewOriginY {
                // pinView 已经达到顶部，直接切换 contentOffsetY
                self.contentOffset.y = max(self.pageCollectionViewOriginY, currentContentOffsetY)
            } else {
    //            self.contentOffset.y = max(contentOffset.y, currentContentOffsetY)
                // 如果 currentContentOffsetY 不为 nil
                // 当向上滚动，整个 ScrollView 向上，直到 contentOffset.y 达到 pageCollectionViewOriginY
                // 当向下滚动，当前page向下，直到 page.contentOffset.y 到达 0.
                // pinView 未滚动到顶部，需要情况切换 contentOffsetY，在 layoutSubviews() 内切换。
                if currentIndex != index {
                    isSwitchToNewPageWhenPinViewNotOnTop = true
                    switchToNewPageWhenPinViewNotInTopContentOffset = contentOffset.y
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
        self.contentSize = CGSize(width: self.bounds.width, height: max(currentSubviewOffsetY, minimumContentHeight))

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

                if isPinViewPaning {
                    let offsetY = scrollView.contentOffset.y
                    pageDict[currentIndex]?.pageListView.bounces = (offsetY > 200)
                }
                pageCurrentOffsetDict[currentIndex] = scrollView.contentOffset.y
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
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
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

                if currentIndex == indexPath.item {
                    page?.pageListView.addGestureRecognizer(pagePanGesture!)
                }
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

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let pagePanGesture = pagePanGesture {
            pageDict[indexPath.item]?.pageListView.removeGestureRecognizer(pagePanGesture)
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard self !== scrollView else { return }
        let index = Int(scrollView.contentOffset.x/scrollView.bounds.size.width)
        horizontalScrollDidEnd(at: index)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if self === scrollView {
            if isPinViewOnTop {
                pageDict[currentIndex]?.pageListView.isCurrentDragging = true
            } else {
                pageDict[currentIndex]?.pageListView.isCurrentDragging = nil
            }
        }
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView === self {
            if isPinViewOnTop {
                pageDict[currentIndex]?.pageListView.isCurrentDragging = false
            } else {
                pageDict[currentIndex]?.pageListView.isCurrentDragging = nil
            }
        } else {
            if !decelerate {
                let index = Int(scrollView.contentOffset.x/scrollView.bounds.size.width)
                horizontalScrollDidEnd(at: index)
            }
        }
    }
}

extension EasyPagingView {
    @objc func pinViewPanGesture(_ gesture: UIPanGestureRecognizer) {

        if gesture.state == .began {
            if !isPinViewPaning {
                self.isScrollEnabled = false
                isPinViewPaning = true
                pageDict[currentIndex]?.pageListView.isScrollEnabled = true
            }
            pinViewDragingBeginOriginY = pagePinView!.frame.origin.y

        } else if gesture.state == .changed {
            let gestureOffsetY = gesture.translation(in: contentView).y
            pagePinView?.frame.origin.y = max(pinInsetTop, pinViewDragingBeginOriginY + gestureOffsetY)
            pageCollectionView.frame.origin.y = (pagePinView!.frame.origin.y + pagePinView!.frame.height)
        } else if gesture.state == .ended {
            let velocityY = gesture.velocity(in: contentView).y
            let gestureOffsetY = gesture.translation(in: contentView).y
            didEndScrolling(velocityY: velocityY, gestureOffsetY: gestureOffsetY)
        }
    }

    func didEndScrolling(velocityY: CGFloat, gestureOffsetY: CGFloat) {
        let panHeight = (bounds.height - pagePinView!.frame.height) / 2
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

        let pinViewDragingEndOriginY = !shouldScrollToBottom ? pinViewOffsetY - bounds.height + pagePinView!.frame.height : pinViewOffsetY
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            self.pagePinView?.frame.origin.y = pinViewDragingEndOriginY
            self.pageCollectionView.frame.origin.y = (self.pagePinView!.frame.origin.y + self.pagePinView!.frame.height)
        } completion: { (success) in
            if success {
                if pinViewDragingEndOriginY == self.pinViewOffsetY {
                    self.isPinViewPaning = false
                    self.pageCollectionView.frame.origin.y = self.pageCollectionViewOffsetY
                    self.pageDict[self.currentIndex]?.pageListView.isScrollEnabled = false
                    self.isScrollEnabled = true

                    for (_, page) in self.pageDict {
                        page.pageListView.isScrollEnabled = false
                    }
                    self.isPaningEndJustNow = true
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
            let isPagePanGestureEnable = isScrollingDown && isReachOnTop && isPinViewPaning
            return isPagePanGestureEnable
        }
        return true
    }
}

