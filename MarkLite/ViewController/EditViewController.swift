//
//  EditViewController.swift
//  Markdown
//
//  Created by zhubch on 2017/6/23.
//  Copyright © 2017年 zhubch. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

enum ExportType: String {
    case pdf
    case html
    case image
    case markdown
    
    var displayName: String {
        switch self {
        case .pdf:
            return /"PDF"
        case .html:
            return /"WebPage"
        case .image:
            return /"Image"
        default:
            return /"Markdown"
        }
    }
}

class EditViewController: UIViewController, ImageSaver, UIScrollViewDelegate, UISplitViewControllerDelegate,UIPopoverPresentationControllerDelegate {
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var textViewWidth: NSLayoutConstraint!
    
    var file: File? {
        didSet {
            self.title = file?.name
        }
    }
    
    var landscape: Bool {
        return windowWidth > windowHeight
    }
    
    var split: Bool {
        if Configure.shared.splitOption.value == .always {
            return true
        }
        if Configure.shared.splitOption.value == .never {
            return false
        }
        return landscape
    }
    
    var timer: Timer?
    var markdownToRender: String?

    var webVC: WebViewController!
    var textVC: TextViewController!

    var webVisible = true
    let bag = DisposeBag()
    let markdownRenderer = MarkdownRender.shared()
    let pdfRender = PdfRender()
    
    override var title: String? {
        didSet {
            markdownRenderer?.title = title
        }
    }
    
    lazy var exportButton: UIBarButtonItem = {
        let export = UIBarButtonItem(image: #imageLiteral(resourceName: "export"), style: .plain, target: self, action: #selector(showExportMenu(_:)))
        return export
    }()
    
    lazy var styleButton: UIBarButtonItem = {
        let export = UIBarButtonItem(image: #imageLiteral(resourceName: "style"), style: .plain, target: self, action: #selector(style(_:)))
        return export
    }()
    
    lazy var previewButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: /"Preview", style: .plain, target: self, action: #selector(preview))
        return button
    }()
    
    lazy var fullscreenButton: UIBarButtonItem = {
        let export = UIBarButtonItem(image: #imageLiteral(resourceName: "fullscreen"), style: .plain, target: self, action: #selector(fullscreen))
        return export
    }()
    
    lazy var filelistButton: UIBarButtonItem = {
        let export = UIBarButtonItem(image: #imageLiteral(resourceName: "nav_files"),
                    landscapeImagePhone: #imageLiteral(resourceName: "nav_files"),
                    style: .plain,
                    target: splitViewController?.displayModeButtonItem.target,
                    action: splitViewController?.displayModeButtonItem.action)
        return export
    }()
    
    lazy var styleVC: UIViewController? = {
        let path = resourcesPath + "/Styles/"
        
        guard let subPaths = FileManager.default.subpaths(atPath: path) else { return nil}
        
        let items = subPaths.map{ $0.replacingOccurrences(of: ".css", with: "")}.filter{!$0.hasPrefix(".")}.sorted(by: >)
        let index = items.index{ Configure.shared.markdownStyle.value == $0 }
        let wraper = OptionsWraper(selectedIndex: index, editable: true, title: /"Style", items: items) {
            Configure.shared.markdownStyle.value = $0.toString
        }

        let vc = OptionsViewController()
        vc.options = wraper
        
        let nav = UINavigationController(rootViewController: vc)
        nav.preferredContentSize = CGSize(width:260, height: 340)
        nav.modalPresentationStyle = .popover

        return nav
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let popGestureRecognizer = self.navigationController?.interactivePopGestureRecognizer {
            scrollView.panGestureRecognizer.require(toFail: popGestureRecognizer)
        }
                
        if self.file != nil {
            setup()
        }
        
        if let splitViewController = self.splitViewController {
            
            navigationItem.leftBarButtonItem  = UIBarButtonItem(image: #imageLiteral(resourceName: "nav_files"),
            landscapeImagePhone: #imageLiteral(resourceName: "nav_files"),
            style: .plain,
            target: self,
            action: #selector(fullscreen))
                
            splitViewController.delegate = self
        }
        
        Configure.shared.splitOption.asObservable().subscribe(onNext: { [unowned self] _ in
            self.textViewWidth.priority = self.split ? UILayoutPriority.required : .defaultLow
            self.textVC.seperator.isHidden = self.split == false
            self.toggleRightBarButton()
        }).disposed(by: bag)
        
        navBar?.setBarTintColor(.navBar)
        navBar?.setContentColor(.navBarTint)
        addNotificationObserver(NSNotification.Name.UIApplicationWillTerminate.rawValue, selector: #selector(applicationWillTerminate))
        addNotificationObserver(NSNotification.Name.UIApplicationDidEnterBackground.rawValue, selector: #selector(applicationWillTerminate))
        addNotificationObserver(Notification.Name.UIApplicationWillChangeStatusBarOrientation.rawValue, selector: #selector(deviceOrientationWillChange))
        addNotificationObserver("FileLoadFinished", selector: #selector(fileLoadFinished(_:)))
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        textViewWidth.priority = split ? UILayoutPriority.required : .defaultLow
        textVC.seperator.isHidden = split == false
        toggleRightBarButton()
        if isPad {
            navigationItem.leftBarButtonItem = landscape ? fullscreenButton : filelistButton
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        file?.save()
    }
    
    func setup() {
        guard let file = self.file else {
            return
        }
                
        textVC.textChangedHandler = { [weak self] text in
            file.text = text
            self?.markdownToRender = text
        }
        
        textVC.offsetChangedHandler = { [weak self] offset in
            self?.webVC.offset = offset
        }

        Configure.shared.markdownStyle.asObservable().subscribe(onNext: { [unowned self] (style) in
            self.markdownRenderer?.styleName = style
            self.markdownToRender = file.text
        }).disposed(by: bag)
        
        Configure.shared.highlightStyle.asObservable().subscribe(onNext: { [unowned self] (style) in
            self.markdownRenderer?.highlightName = style
            self.markdownToRender = file.text
        }).disposed(by: bag)
        
        timer = Timer.runThisEvery(seconds: 0.05) { [weak self] _ in
            guard let this = self else { return }
            if let markdown = this.markdownToRender {
                this.webVC.htmlString = this.markdownRenderer?.renderMarkdown(markdown) ?? ""
                this.markdownToRender = nil
            }
        }
        
        textVC.editView.text = file.text
        textVC.textChanged()
    }
    
    @objc func applicationWillTerminate() {
        file?.save()
    }
    
    @objc func deviceOrientationWillChange() {
        splitViewController?.preferredDisplayMode = .automatic
    }
    
    @objc func fileLoadFinished(_ noti: Notification) {
        guard let file = noti.object as? File else { return }
        self.file = file
    }
    
    @objc func style(_ sender: UIBarButtonItem) {
        guard let styleVC = self.styleVC, let popoverVC = styleVC.popoverPresentationController else {
            return
        }
        popoverVC.backgroundColor = UIColor.white
        popoverVC.delegate = self
        popoverVC.barButtonItem = sender
        present(styleVC, animated: true, completion: nil)
    }
    
    @objc func preview() {
        textVC.editView.resignFirstResponder()
        scrollView.setContentOffset(CGPoint(x:windowWidth , y:0), animated: true)
        toggleRightBarButton()
    }
    
    @objc func fullscreen() {
        UIView.animate(withDuration: 0.5) {
            if self.splitViewController?.preferredDisplayMode != .primaryHidden {
                self.splitViewController?.preferredDisplayMode = .primaryHidden
            } else {
                self.splitViewController?.preferredDisplayMode = .allVisible
            }
        }
    }
    
    func toggleRightBarButton() {
        webVisible = scrollView.contentOffset.x > windowWidth - 10
        
        if webVisible || split {
            navigationItem.rightBarButtonItems = [exportButton,styleButton]
        } else {
            navigationItem.rightBarButtonItems = [previewButton]
        }
    }
    
    @objc func showExportMenu(_ sender: Any) {
        textVC.editView.resignFirstResponder()
        
        let items = [ExportType.markdown,.pdf,.html,.image]
        var pos = CGPoint(x: windowWidth - 140, y: 65)
        if let view = sender as? UIView {
            pos = view.origin
            if self.landscape {
                pos.x += 44
            } else {
                pos.y += 44
            }
        }
        
        func export(_ index: Int) {
            guard let url = self.url(for: items[index]) else { return }
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = sender as? UIView
            vc.popoverPresentationController?.sourceRect = (sender as? UIView)?.frame ?? CGRect(x: 62, y: 20, w: 44, h: 44)
            self.presentVC(vc)
        }
        
        MenuView(items: items.map{$0.displayName},
                 postion: pos) { (index) in
                    if index > 0 {
                        self.doIfPro {
                            export(index)
                        }
                    } else {
                        export(index)
                    }
            }.show()
    }
    
    func doIfPro(_ task: (() -> Void)) {
        if Configure.shared.isPro {
            task()
            return
        }
        showAlert(title: /"PremiumOnly", message: /"PremiumTips", actionTitles: [/"SubscribeNow",/"Cancel"], textFieldconfigurationHandler: nil) { [unowned self](index) in
            if index == 0 {
                let sb = UIStoryboard(name: "Settings", bundle: Bundle.main)
                let vc = sb.instantiateVC(PurchaseViewController.self)!
                let nav = UINavigationController(rootViewController: vc)
                self.presentVC(nav)
            }
        }
    }
    
    func url(for type: ExportType) -> URL? {
        guard let file = self.file else { return nil }
        switch type {
        case .pdf:
            let data = pdfRender.render(formatter: self.webVC.webView.viewPrintFormatter())
            let path = tempPath + "/" + file.name + ".pdf"
            let url = URL(fileURLWithPath: path)
            do {
                try data.write(to: url)
            } catch {
                print(error.localizedDescription)
            }
            return url
        case .image:
            guard let img = self.webVC.webView.scrollView.snap, let _ = UIImagePNGRepresentation(img) else { return nil }
            saveImage(img)
            return nil
        case .markdown:
            return URL(fileURLWithPath: file.path)
        case .html:
            guard let data = self.webVC.htmlString.data(using: String.Encoding.utf8) else { return nil }
            let path = tempPath + "/" + file.name + ".html"
            let url = URL(fileURLWithPath: path)
            try? data.write(to: url)
            return url
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? TextViewController {
            textVC = vc
        } else if let vc = segue.destination as? WebViewController {
            webVC = vc
        }
    }
    
    override func shouldBack() -> Bool {
        if scrollView.contentOffset.x > 10 {
            scrollView.setContentOffset(CGPoint(x:0,y:0), animated: true)
            return false
        }
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        file?.save()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        toggleRightBarButton()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        toggleRightBarButton()
    }
    
    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewControllerDisplayMode) {

    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
        
    deinit {
        timer?.invalidate()
        removeNotificationObserver()
        print("deinit edit_vc")
    }
}
