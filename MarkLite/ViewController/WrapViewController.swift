//
//  WrapViewController.swift
//  Markdown
//
//  Created by zhubch on 2017/8/2.
//  Copyright © 2017年 zhubch. All rights reserved.
//

import UIKit
import RxSwift

class WrapViewController: UISplitViewController, UISplitViewControllerDelegate {

    let bag = DisposeBag()
            
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        view.setBackgroundColor(.background)
    }
    
    public func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return isPhone
    }
}
