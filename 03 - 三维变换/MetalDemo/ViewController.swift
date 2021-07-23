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
        mtkview.preferredFramesPerSecond = 25
    }

    @IBAction func switchAction(_ sender: UISwitch) {
        let index = sender.tag
        
        switch index {
        case 0:
            Render.Axis.xFlag = sender.isOn
        case 1:
            Render.Axis.yFlag = sender.isOn
        case 2:
            Render.Axis.zFlag = sender.isOn
        case 3:
            Render.Axis.xFlag = sender.isOn
            Render.Axis.yFlag = sender.isOn
        case 4:
            Render.Axis.xFlag = sender.isOn
            Render.Axis.zFlag = sender.isOn
        case 5:
            Render.Axis.yFlag = sender.isOn
            Render.Axis.zFlag = sender.isOn
        case 6:
            Render.Axis.xFlag = sender.isOn
            Render.Axis.yFlag = sender.isOn
            Render.Axis.zFlag = sender.isOn
        default:
            break
        }
    }
    
    @IBAction func resetAction(_ sender: UIButton) {
        Render.Axis.xFlag = false
        Render.Axis.yFlag = false
        Render.Axis.zFlag = false
        
        Render.Axis.x = 0
        Render.Axis.y = 0
        Render.Axis.z = 0
    }
    
}

