//
//  SettingsViewController.swift
//  Markdown
//
//  Created by zhubch on 2017/6/23.
//  Copyright © 2017年 zhubch. All rights reserved.
//

import UIKit
import RxSwift

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var textField: UITextField?
    
    let themeSwitch = UISwitch(x: 0, y: 9, w: 60, h: 60)
    let assitBarSwitch = UISwitch(x: 0, y: 9, w: 60, h: 60)
    
    var items: [(String,[(String,String,Selector)])] {
        var section = [
            ("WebDAV","",#selector(webdav)),
            ("AssistKeyboard","",#selector(assistBar)),
            ("ArrangeKeyboardBar","",#selector(arrange)),
            ]
        if isPad {
            section.append(("SplitOptions","",#selector(splitOption)))
        }
        var items = [
            ("功能",section),
            ("外观",[
                ("NightMode","",#selector(night)),
                ("Theme","",#selector(theme)),
                ("Style","",#selector(style)),
                ("CodeStyle","",#selector(codeStyle)),
                ]),
            ("支持一下",[
                ("RateIt","",#selector(rate)),
                ("Contact","",#selector(feedback))
                ])
        ]
        if !Configure.shared.isPro {
            items.insert(("高级帐户",[("Premium","",#selector(premium))]), at: 0)
        }
        return items;
    }
    
    let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = /"Settings"
        navBar?.setTintColor(.navTint)
        navBar?.setBackgroundColor(.navBar)
        navBar?.setTitleColor(.navTitle)
        tableView.setBackgroundColor(.tableBackground)
        tableView.setSeparatorColor(.primary)

        themeSwitch.setTintColor(.tint)
        assitBarSwitch.setTintColor(.tint)

        themeSwitch.isOn = Configure.shared.theme.value == .black
        assitBarSwitch.isOn = Configure.shared.isAssistBarEnabled.value
        
        themeSwitch.addTarget(self, action: #selector(night(_:)), for: .valueChanged)
        assitBarSwitch.addTarget(self, action: #selector(assistBar(_:)), for: .valueChanged)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        themeSwitch.x = view.w - 64
        assitBarSwitch.x = view.w - 64
    }
    
    @objc func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items[section].1.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settings", for: indexPath)

        let item = items[indexPath.section].1[indexPath.row]
        cell.textLabel?.text = /(item.0)
        cell.detailTextLabel?.text = /(item.1)
        
        if item.0 == "AssistKeyboard" {
            cell.addSubview(assitBarSwitch)
            cell.accessoryType = .none
        }
        if item.0 == "NightMode" {
            cell.addSubview(themeSwitch)
            cell.accessoryType = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = items[indexPath.section].1[indexPath.row]
        if item.0 == "AssistKeyboard" || item.0 == "NightMode" {
            return
        }
        perform(item.2)
    }
}

extension SettingsViewController {
    
    func doIfPro(_ task: (() -> Void)) {
        if Configure.shared.isPro {
            task()
            return
        }
        showAlert(title: /"PremiumOnly", message: /"PremiumTips", actionTitles: [/"SubscribeNow",/"Cancel"], textFieldconfigurationHandler: nil) { [unowned self](index) in
            if index == 0 {
                self.premium()
            }
        }
    }
    
    @objc func premium() {
        let sb = UIStoryboard(name: "Settings", bundle: Bundle.main)
        let vc = sb.instantiateVC(PurchaseViewController.self)!
        dismiss(animated: false) {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            let date = Date(fromString: "2019-10-04", format: "yyyy-MM-dd")!
            let now = Date()
            if now > date {
                nav.modalPresentationStyle = .formSheet
            } else {
                nav.modalPresentationStyle = .fullScreen
            }
            UIApplication.shared.keyWindow?.rootViewController?.presentVC(nav)
        }
    }
    
    @objc func splitOption() {
        let items = [SplitOption.automatic,.never,.always]
        let index = items.index{ Configure.shared.splitOption.value == $0 }

        let wraper = OptionsWraper(selectedIndex: index, editable: false, title: /"SplitOptions", items: items) {
            Configure.shared.splitOption.value = $0 as! SplitOption
        }
        let vc = OptionsViewController()
        vc.options = wraper
        pushVC(vc)
    }
    
    @objc func rate() {
        Configure.shared.hasRate = true
        UIApplication.shared.openURL(URL(string: rateUrl)!)
    }
    
    @objc func feedback() {
        showAlert(title: /"Contact", message: /"ContactMessage", actionTitles: [/"Cancel",/"Email",/"Weibo"]) { index in
            if index == 1 {
                UIApplication.shared.openURL(URL(string: emailUrl)!)
            } else if index == 2 {
                UIApplication.shared.openURL(URL(string: weiboURL)!)
            }
        }
    }
    
    @objc func night(_ sender: UISwitch) {
        Configure.shared.theme.value = sender.isOn ? .black : .white
        if sender.isOn {
            Configure.shared.markdownStyle.value = "GitHub Dark"
            Configure.shared.highlightStyle.value = "tomorrow-night"
        } else {
            Configure.shared.markdownStyle.value = "GitHub"
            Configure.shared.highlightStyle.value = "tomorrow"
        }
    }
    
    @objc func assistBar(_ sender: UISwitch) {
        Configure.shared.isAssistBarEnabled.value = sender.isOn
    }
    
    @objc func arrange() {

    }
    
    @objc func webdav() {
        performSegue(withIdentifier: "webdav", sender: nil)
    }
    
    @objc func theme() {
        let items = [Theme.white,.black,.pink,.green,.blue,.purple,.red]
        let index = items.index{ Configure.shared.theme.value == $0 }

        let wraper = OptionsWraper(selectedIndex: index, editable: false, title: /"Theme", items: items) {
            Configure.shared.theme.value = $0 as! Theme
        }
        let vc = OptionsViewController()
        vc.options = wraper
        pushVC(vc)
    }
    
    @objc func style() {
        let path = resourcesPath + "/Styles/"
        
        guard let subPaths = FileManager.default.subpaths(atPath: path) else { return }
        
        let items = subPaths.map{ $0.replacingOccurrences(of: ".css", with: "")}.filter{!$0.hasPrefix(".")}.sorted(by: >)
        let index = items.index{ Configure.shared.markdownStyle.value == $0 }
        let wraper = OptionsWraper(selectedIndex: index, editable: true, title: /"Style", items: items) {
            Configure.shared.markdownStyle.value = $0.toString
        }

        let vc = OptionsViewController()
        vc.options = wraper
        pushVC(vc)
    }
    
    @objc func codeStyle() {
        let path = resourcesPath + "/Highlight/highlight-style/"
        
        guard let subPaths = FileManager.default.subpaths(atPath: path) else { return }
        
        let items = subPaths.map{ $0.replacingOccurrences(of: ".css", with: "")}.filter{!$0.hasPrefix(".")}
        let index = items.index{ Configure.shared.highlightStyle.value == $0 }
        let wraper = OptionsWraper(selectedIndex: index, editable: false, title: /"CodeStyle", items: items) {
            Configure.shared.highlightStyle.value = $0.toString
        }
        let vc = OptionsViewController()
        vc.options = wraper
        pushVC(vc)
    }

}
