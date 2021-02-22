//
//  ViewController.swift
//  Demo
//
//  Created by Quanhua Peng on 2021/1/10.
//

import UIKit

class ViewController: UIViewController {

    let modes: [String] = ["没有headerView", "普通headerView", "长headerView"]
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "EasyPagingView"
        self.view.backgroundColor = .white
        let tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        view.addSubview(tableView)

    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return modes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        }
        cell?.textLabel?.text = modes[indexPath.row]
        return cell!
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.row {
        case 0:
            let viewController = WithoutHeaderViewController()
            self.navigationController?.pushViewController(viewController, animated: true)
        case 1:
            let viewController = NormalHeaderViewController()
            self.navigationController?.pushViewController(viewController, animated: true)
        case 2:
            let viewController = LongHeaderViewController()
            self.navigationController?.pushViewController(viewController, animated: true)
        default:
            break
        }
    }
}

