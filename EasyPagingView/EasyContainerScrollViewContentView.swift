//
//  EasyContainerScrollViewContentView.swift
//  ScrollViewDemo
//
//  Created by quanhua on 2020/12/20.
//

import UIKit
 
class EasyContainerScrollViewContentView: UIView {

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        
        if let containerView = superview as? EasyPagingView {
            containerView.didAddSubviewToContainer(subview)
        } else if let containerView = superview as? EasyScrollContainerView {
            containerView.didAddSubviewToContainer(subview)
        }
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        
        if let containerView = superview as? EasyPagingView {
            containerView.willRemoveSubviewFromContainer(subview)
        } else if let containerView = superview as? EasyScrollContainerView {
            containerView.willRemoveSubviewFromContainer(subview)
        }
        
        super.willRemoveSubview(subview)
    }

}
