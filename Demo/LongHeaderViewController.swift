//
//  LongHeaderViewController.swift
//  Demo
//
//  Created by Quanhua Peng on 2021/2/17.
//

import UIKit
import EasyPagingView
import SnapKit

class LongHeaderViewController: UIViewController {

    var segmentView: SegmentView!
    var containerView: EasyPagingView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1)
        self.title = "长 HeaderView"
        let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
        let safeAreaInsetsTop =  (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0)
        let containerViewHeight = view.bounds.height - navigationBarHeight - safeAreaInsetsTop
        let frame = CGRect(x: 0, y: safeAreaInsetsTop + navigationBarHeight, width: view.bounds.width, height: containerViewHeight)
        containerView = EasyPagingView(frame: frame)
        containerView.dataSource = self
        containerView.contentInsetAdjustmentBehavior = .never
        self.view.addSubview(containerView)
        
        let tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.backgroundColor = UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.sectionHeaderHeight = 44
        tableView.sectionFooterHeight = 0
        tableView.register(RelevantCell.self, forCellReuseIdentifier: "RelevantCell")
        tableView.register(ProfileCell.self, forCellReuseIdentifier: "ProfileCell")
        tableView.register(ActorViewCell.self, forCellReuseIdentifier: "ActorViewCell")
        let tableHeaderView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 250)))
        tableHeaderView.image = UIImage(named: "haibao")
        tableView.tableHeaderView = tableHeaderView
        var tableFooterViewFrame = CGRect.zero
        tableFooterViewFrame.size.height = 20
        tableView.tableFooterView = UIView(frame: tableFooterViewFrame)
        tableView.separatorStyle = .none
        containerView.headerView = tableView

        segmentView = SegmentView(frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 64)))
        segmentView.backgroundColor = .white
        segmentView.layer.cornerRadius = 12
        segmentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        segmentView.titleList = ["影评", "讨论"]
        segmentView.pageCollectionView = containerView.pageCollectionView
        let lineOriginX = (UIScreen.main.bounds.width - 40)/2
        let lineView = UIView(frame: CGRect(x: lineOriginX, y: 10, width: 40, height: 6))
        lineView.backgroundColor = .lightGray
        lineView.layer.cornerRadius = 3
        segmentView.addSubview(lineView)
        containerView.segmentView = segmentView
        segmentView.reloadData()
        containerView.reloadData()
    }
}

extension LongHeaderViewController: EasyPagingViewDataSource {
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

extension LongHeaderViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 2:
            return 4
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 100
        case 1:
            return 150
        case 2:
            return 100
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let profileCell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath)
            return profileCell
        case 1:
            let actorViewCell = tableView.dequeueReusableCell(withIdentifier: "ActorViewCell", for: indexPath)
            return actorViewCell
        case 2:
            let relevantCell = tableView.dequeueReusableCell(withIdentifier: "RelevantCell", for: indexPath)
            return relevantCell
        default:
            break
        }
        fatalError()
    }
    
}

extension LongHeaderViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "简介"
        case 1:
            return "演职员"
        case 2:
            return "相关推荐"
        default:
            return nil
        }
    }
}

class ProfileCell: UITableViewCell {
    
    let label = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1)
        label.numberOfLines = 0
        label.text = "一场谋杀案使银行家安迪蒙冤入狱，谋杀妻子及其情人的指控将囚禁他终生。"
        label.textColor = .white
        contentView.addSubview(label)
        
        label.snp.remakeConstraints { (make) in
            make.edges.equalToSuperview().inset(20)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ActorViewCell: UITableViewCell, UICollectionViewDataSource {
    
    var collectionView: UICollectionView!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        
        let collectionViewWidth = UIScreen.main.bounds.width
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.itemSize = CGSize(width: 80, height: 150)
        flowLayout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: collectionViewWidth, height: 120), collectionViewLayout: flowLayout)
        collectionView.register(ActorCell.self, forCellWithReuseIdentifier: "ActorCell")
        collectionView.backgroundColor = UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1)
        collectionView.dataSource = self
        collectionView.contentInset.left = 20
        collectionView.contentInset.right = 20
        collectionView.showsHorizontalScrollIndicator = false
        contentView.addSubview(collectionView)
        
        collectionView.snp.remakeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ActorCell", for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }
    
}

class ActorCell: UICollectionViewCell {
    var coverImageView: UIImageView!
    var titleLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1)
        coverImageView = UIImageView()
        coverImageView.image = UIImage(named: "andi")
        contentView.addSubview(coverImageView)
        
        titleLabel = UILabel()
        titleLabel.text = "蒂姆·罗宾斯"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 12)
        contentView.addSubview(titleLabel)
        
        
        coverImageView.snp.remakeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview().inset(20)
            make.height.equalTo(100)
        }
        
        titleLabel.snp.remakeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(coverImageView.snp.bottom).offset(10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RelevantCell: UITableViewCell {
    var coverImageView: UIImageView!
    var titleLabel: UILabel!
    var subTitleLabel: UILabel!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1)
        self.selectionStyle = .none
        coverImageView = UIImageView()
        coverImageView.image = UIImage(named: "xiao")
        contentView.addSubview(coverImageView)
        
        titleLabel = UILabel()
        titleLabel.text = "肖申克的救赎"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 15)
        contentView.addSubview(titleLabel)
        
        subTitleLabel = UILabel()
        subTitleLabel.text = "[美]斯蒂芬·金/2006/人民文学出版社"
        subTitleLabel.textColor = .white
        subTitleLabel.font = UIFont.systemFont(ofSize: 12)
        contentView.addSubview(subTitleLabel)
        
        coverImageView.snp.remakeConstraints { (make) in
            make.left.top.equalToSuperview().inset(20)
            make.width.equalTo(64)
            make.height.equalTo(80)
        }
        
        titleLabel.snp.remakeConstraints { (make) in
            make.left.equalTo(coverImageView.snp.right).offset(20)
            make.top.equalTo(coverImageView)
            make.width.equalTo(150)
        }
        
        subTitleLabel.snp.remakeConstraints { (make) in
            make.left.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.right.equalToSuperview().inset(20)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
