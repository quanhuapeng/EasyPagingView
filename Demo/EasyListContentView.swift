//
//  EasyListContentView.swift
//  ScrollViewDemo
//
//  Created by Quanhua Peng on 2020/12/26.
//

import UIKit
import MJRefresh
import EasyPagingView

class EasyListContentView: UIView {

    var collectionView: UICollectionView!
    var totalCount: Int = 30
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: frame.width, height: 100)
        collectionView = UICollectionView(frame: CGRect(origin: .zero, size: frame.size), collectionViewLayout: flowLayout)
        collectionView.dataSource = self
//        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = .white
        collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.contentInset.bottom = 0
        
        addSubview(collectionView)
        
        collectionView.mj_header = MJRefreshNormalHeader(refreshingBlock: { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                self?.totalCount = 20
                self?.collectionView.reloadData()
                self?.collectionView.mj_header?.endRefreshing()
            }
        })
        
        let footer = MJRefreshBackNormalFooter(refreshingBlock: { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                self?.totalCount += 20
                self?.collectionView.reloadData()
                self?.collectionView.mj_footer?.endRefreshing()
            }
        })
        footer.setTitle("", for: .noMoreData)
        collectionView.mj_footer = footer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EasyListContentView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CollectionViewCell
        cell.label.text = "\(indexPath.item)"
        return cell
    }
}

extension EasyListContentView: EasyPagingViewDelegate {
    var pageView: UIView {
        return self
    }
    
    var pageListView: UICollectionView {
        return collectionView
    }
}

class CollectionViewCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.frame = CGRect(x: 20, y: 20, width: 100, height: 15)
        contentView.addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EasyListContentView: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return totalCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        }
        cell?.textLabel?.text = "\(indexPath.row)"
        cell?.backgroundColor = .clear
        return cell!
    }
    
    
}
