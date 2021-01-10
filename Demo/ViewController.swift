//
//  ViewController.swift
//  Demo
//
//  Created by Quanhua Peng on 2021/1/10.
//

import UIKit
import EasyPagingView

class ViewController: UIViewController {
    
    var view0: UIScrollView!
    let view1 = UIView()
    var view2: EasyListContentView!
    let containerView = EasyPagingView()

    override func viewDidLoad() {
        super.viewDidLoad()
        let viewWidth = UIScreen.main.bounds.width
        let viewHeight = UIScreen.main.bounds.height
        
        containerView.frame = self.view.bounds
        containerView.dataSource = self
        containerView.dataSource = self
        containerView.contentInsetAdjustmentBehavior = .never
//        containerView.pinInsetTop = 64
        self.view.addSubview(containerView)
        
        view0 = UIScrollView(frame: CGRect(origin: .zero, size: CGSize(width: viewWidth, height: 400)))
        view0.contentSize = CGSize(width: viewWidth, height: viewHeight*1.2)
        view0.backgroundColor = .purple
        containerView.pageHeaderView = view0
        
        view1.frame = CGRect(origin: .zero, size: CGSize(width: viewWidth, height: 64))
        view1.backgroundColor = .blue
        containerView.pagePinView = view1
        
        containerView.reloadData()

        
    }
}

extension ViewController: EasyPagingViewDataSource {
    func numberOfLists(in easyPagingView: EasyPagingView) -> Int {
        return 3
    }
    
    func easyPagingView(_ easyContainerScrollView: EasyPagingView, pageForItemAt index: Int) -> EasyPagingViewDelegate {
        let cell = EasyListContentView(frame: self.view.bounds)
        if index%2 == 0 {
            cell.pageListView.backgroundColor = .cyan
        }
        return cell
    }
}

