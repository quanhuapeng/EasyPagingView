//
//  UIScrollView+Swizzle.swift
//  EasyPagingViewDemo
//
//  Created by Quanhua Peng on 2021/1/10.
//  Copyright © 2021 pengquanhua. All rights reserved.
//

import UIKit

extension UIScrollView {
    
    private struct AssociatedKeys {
        static var isEasyDraggingEnableKey = "isEasyDraggingEnableKey"
        static var isCurrentDraggingEnableKey = "isCurrentDraggingEnableKey"
    }
    
    var isCurrentDragging: Bool? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.isCurrentDraggingEnableKey) as? Bool
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isCurrentDraggingEnableKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    @objc func isEasyDragging() -> Bool {
        if let isCurrentDragging =  isCurrentDragging {
            return isCurrentDragging
        }
        return isEasyDragging()
    }
    
    static let swizzleIsDragging: () = {
        let scrollViewOriginalSelector = #selector(getter: UICollectionView.isDragging)
        let tableViewSwizzledSelector = #selector(UICollectionView.isEasyDragging)
        
        swizzleMethod(scrollViewOriginalSelector, withSelector: tableViewSwizzledSelector)
    }()
    
    static func swizzleMethod(_ selector: Selector, withSelector: Selector) {
        let originalSelector = class_getInstanceMethod(self, selector)
        let swizzledSelector = class_getInstanceMethod(self, withSelector)
        if let originalSelector = originalSelector, let swizzledSelector = swizzledSelector {
            method_exchangeImplementations(originalSelector, swizzledSelector)
        }
    }
}
