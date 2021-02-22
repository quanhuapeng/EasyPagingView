//
//  NormalHeaderViewController.swift
//  Demo
//
//  Created by Quanhua Peng on 2021/2/17.
//

import UIKit
import EasyPagingView

class NormalHeaderViewController: UIViewController {
    
    var containerView: EasyPagingView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.title = "普通 HeaderView"
        let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
        let safeAreaInsetsTop =  (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0)
        let containerViewHeight = view.bounds.height - navigationBarHeight - safeAreaInsetsTop
        let frame = CGRect(x: 0, y: safeAreaInsetsTop + navigationBarHeight, width: view.bounds.width, height: containerViewHeight)
        containerView = EasyPagingView(frame: frame)
        containerView.dataSource = self
        containerView.contentInsetAdjustmentBehavior = .never
        self.view.addSubview(containerView)
        
        let headerView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 250)))
        headerView.image = UIImage(named: "header")
        containerView.headerView = headerView
        
        let segmentView = SegmentView(frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 52)))
        segmentView.backgroundColor = .white
        segmentView.titleList = ["A", "B"]
        segmentView.pageCollectionView = containerView.pageCollectionView
        containerView.segmentView = segmentView
        segmentView.reloadData()
        containerView.reloadData()
    }
}

extension NormalHeaderViewController: EasyPagingViewDataSource {
    func easyPagingView(_ easyPagingView: EasyPagingView, pageForItemAt index: Int) -> EasyPagingListViewDelegate {
        let cell = EasyListContentView(frame: self.view.bounds)
        if index%2 == 0 {
            cell.pageListView.backgroundColor = .cyan
        }
        return cell
    }

    func numberOfLists(in easyPagingView: EasyPagingView) -> Int {
        return 2
    }
}
