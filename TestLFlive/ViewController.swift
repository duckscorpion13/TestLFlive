//
//  ViewController.swift
//  TestLFlive
//
//  Created by derekyang on 2020/12/3.
//

import UIKit

class ViewController: UIViewController, LBDLiveMgrDelegate {
    
    lazy var liveMgr: LBDLiveMgr? = {
        let mgr = LBDLiveMgr(view: self.view)
        mgr.delegate = self
        
        return mgr
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.liveMgr?.pushKit.preView = self.view
        self.liveMgr?.pushKit.running = true
    }


}

