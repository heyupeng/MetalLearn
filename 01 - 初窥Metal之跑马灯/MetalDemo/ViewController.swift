//
//  ViewController.swift
//  MetalDemo
//
//  Created by Peng on 2021/7/19.
//

import UIKit
import Metal
import MetalKit

class ViewController: UIViewController {
    
    @IBOutlet weak var mtkview: MTKView!
    
    var render: Render!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        render = Render(mtkView: mtkview)
        mtkview.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0, alpha: 1)
        mtkview.preferredFramesPerSecond = 10
    }


}

