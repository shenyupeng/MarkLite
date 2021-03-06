//
//  Configure.swift
//  Markdown
//
//  Created by zhubch on 2017/7/1.
//  Copyright © 2017年 zhubch. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Zip

enum SplitOption: String {
    case automatic
    case never
    case always
    
    var displayName: String {
        switch self {
        case .automatic:
            return /"Automatic"
        case .never:
            return /"Never"
        case .always:
            return /"Always"
        }
    }
}

enum SortOption: String {
    case modifyDate
    case name
    case type

    var displayName: String {
        switch self {
        case .type:
            return /"SortByType"
        case .name:
            return /"SortByName"
        case .modifyDate:
            return /"SortByModifyDate"
        }
    }
    
    var next: SortOption {
        switch self {
        case .type:
            return .modifyDate
        case .name:
            return .type
        case .modifyDate:
            return .name
        }
    }
}

enum DarkModeOption: String {
    case dark
    case light
    case system

    var displayName: String {
        switch self {
        case .dark:
            return /"KeepDarkMode"
        case .light:
            return /"DisableDarkMode"
        case .system:
            return /"FollowSystem"
        }
    }
    
    static var defaultDarkOption: DarkModeOption = {
        if #available(iOS 13.0, *) {
            return .system
        }
        return .light
    }()
}

class Configure: NSObject, NSCoding {
    
    static let configureFile = configPath + "/Configure.plist"
    
    var newVersionAvaliable = false
        
    var currentVerion: String?
    var rateAlertDate = Date().daysAgo(19)
    var expireDate = Date.longlongAgo()
    var showExtensionName = false
    var impactFeedback = true
    let isAssistBarEnabled = Variable(true)
    let markdownStyle = Variable("GitHub")
    let highlightStyle = Variable("tomorrow")
    let theme = Variable(Theme.white)
    let splitOption = Variable(SplitOption.automatic)
    var sortOption = SortOption.modifyDate
    let darkOption = Variable(DarkModeOption.defaultDarkOption)
    var keyboardBarItems = ["-","`","$","/","\"","?","@","(",")","[","]","|","#","*","=","+","<",">"]
    var recentImages = [URL]()

    var isPro: Bool {
        return expireDate.isFuture
    }
    
    override init() {
        super.init()
    }
    
    static let shared: Configure = {

        if let old = NSKeyedUnarchiver.unarchiveObject(withFile: configureFile) as? Configure {
            old.setup()
            return old
        }
        
        let configure = Configure()
        configure.reset()
        return configure
    }()
    
    func setup() {
        checkProAvailable()
        if appVersion != currentVerion {
            upgrade()
        }
        currentVerion = appVersion
    }
    
    func reset() {
        rateAlertDate = Date().daysAgo(19)
        expireDate = Date.longlongAgo()
        currentVerion = appVersion
        markdownStyle.value = "GitHub"
        highlightStyle.value = "tomorrow"
        theme.value = .white
        splitOption.value = .automatic
        sortOption = .modifyDate
        darkOption.value = DarkModeOption.defaultDarkOption
        showExtensionName = false
        impactFeedback = true
        
        let destStylePath = URL(fileURLWithPath: supportPath)
        try! Zip.unzipFile(Bundle.main.url(forResource: "Resources", withExtension: "zip")!, destination: destStylePath, overwrite: true, password: nil, progress: nil)
        
        if let path = Bundle.main.path(forResource: /"Instructions", ofType: "md") {
            let newPath = documentPath + "/" + /"Instructions" + ".md"
            try? FileManager.default.copyItem(atPath: path, toPath: newPath)
        }
        if let path = Bundle.main.path(forResource: /"Syntax", ofType: "md") {
            let newPath = documentPath + "/" + /"Syntax" + ".md"
            try? FileManager.default.copyItem(atPath: path, toPath: newPath)
        }
        
        setup()
    }
    
    func upgrade() {
        rateAlertDate = Date()
        impactFeedback = true

        let tempPathURL = URL(fileURLWithPath: tempPath)
        try! Zip.unzipFile(Bundle.main.url(forResource: "Resources", withExtension: "zip")!, destination: tempPathURL, overwrite: true, password: nil, progress: nil)
        let tempStylePath = tempPath + "/Resources/Styles"
        let destStylePath = supportPath + "/Resources/Styles"
        FileManager.default.subpaths(atPath: tempStylePath)?.filter{ $0.hasSuffix(".css") }.forEach{ subpath in
            let fullPath = tempStylePath + "/" + subpath
            let newPath = destStylePath + "/" + subpath
            try? FileManager.default.removeItem(atPath: newPath)
            try? FileManager.default.moveItem(atPath: fullPath, toPath: newPath)
        }
        
        if let path = Bundle.main.path(forResource: /"Instructions", ofType: "md") {
            let newPath = documentPath + "/" + /"Instructions" + ".md"
            if FileManager.default.fileExists(atPath: newPath) {
                try? FileManager.default.removeItem(atPath: newPath)
                try? FileManager.default.copyItem(atPath: path, toPath: newPath)
            }
        }
        if let path = Bundle.main.path(forResource: /"Syntax", ofType: "md") {
            let newPath = documentPath + "/" + /"Syntax" + ".md"
            if FileManager.default.fileExists(atPath: newPath) {
                try? FileManager.default.removeItem(atPath: newPath)
                try? FileManager.default.copyItem(atPath: path, toPath: newPath)
            }
        }        
    }
    
    func save() {
        NSKeyedArchiver.archiveRootObject(self, toFile: Configure.configureFile)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(currentVerion, forKey: "currentVersion")
        aCoder.encode(impactFeedback, forKey: "impactFeedback")
        aCoder.encode(showExtensionName, forKey: "showExtensionName")
        aCoder.encode(isAssistBarEnabled.value, forKey: "isAssistBarEnabled")
        aCoder.encode(markdownStyle.value, forKey: "markdownStyle")
        aCoder.encode(highlightStyle.value, forKey: "highlightStyle")
        aCoder.encode(theme.value.rawValue, forKey: "theme")
        aCoder.encode(splitOption.value.rawValue, forKey: "splitOption")
        aCoder.encode(darkOption.value.rawValue, forKey: "darkOption")
        aCoder.encode(sortOption.rawValue, forKey: "sortOption")
        aCoder.encode(rateAlertDate, forKey: "rateAlertDate")
        aCoder.encode(expireDate, forKey: "expireDate")
        aCoder.encode(recentImages, forKey: "recentImages")
        aCoder.encode(false, forKey: "isPro")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        currentVerion = aDecoder.decodeObject(forKey: "currentVersion") as? String
        rateAlertDate = aDecoder.decodeObject(forKey: "rateAlertDate") as? Date ?? Date().daysAgo(19)
        expireDate = aDecoder.decodeObject(forKey: "expireDate") as? Date ?? Date.longlongAgo()
        recentImages = aDecoder.decodeObject(forKey: "recentImages") as? [URL] ?? []
        impactFeedback = aDecoder.decodeBool(forKey: "impactFeedback")
        showExtensionName = aDecoder.decodeBool(forKey: "showExtensionName")
        isAssistBarEnabled.value = aDecoder.decodeBool(forKey: "isAssistBarEnabled")
        markdownStyle.value = aDecoder.decodeObject(forKey: "markdownStyle") as? String ?? "GitHub"
        highlightStyle.value = aDecoder.decodeObject(forKey: "highlightStyle") as? String ?? "tomorrow"
        theme.value = Theme(rawValue:aDecoder.decodeObject(forKey: "theme") as? String ?? "") ?? .white
        splitOption.value = SplitOption(rawValue: aDecoder.decodeObject(forKey: "splitOption") as? String ?? "") ?? .automatic
        darkOption.value = DarkModeOption(rawValue: aDecoder.decodeObject(forKey: "darkOption") as? String ?? "") ?? DarkModeOption.defaultDarkOption
        sortOption = SortOption(rawValue: aDecoder.decodeObject(forKey: "sortOption") as? String ?? "") ?? .modifyDate
        let isPro = aDecoder.decodeBool(forKey: "isPro")
        if isPro {
            expireDate = Date.distantFuture
        }
    }
    
    func checkProAvailable(_ completion:((Bool)->Void)? = nil){
//        #if DEBUG
//            self.expireDate = Date.distantFuture
//            completion?(self.isPro)
//            return
//        #endif

        IAP.validateReceipt(itunesSecret) { (statusCode, products, json) in
            defer {
                DispatchQueue.main.async {
                    print("会员到期\(self.expireDate.readableDate())")
                    print("会员状态\(self.isPro)")
                    completion?(self.isPro)
                }
            }
            if let code = statusCode {
                if code == ReceiptStatus.noRecipt.rawValue {
                    self.expireDate = Date.longlongAgo()
                    return
                }
            }
            guard let products = products else {
                return
            }
            print("products: \(products)")
            let proIdentifier = [premiumForeverProductID,premiumYearlyProductID,premiumMonthlyProductID]
            self.expireDate = proIdentifier.map{ products[$0] ?? Date(timeIntervalSince1970: 0) }.max() ?? Date(timeIntervalSince1970: 0)
        }
    }
}
