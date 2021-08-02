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
        mtkview.preferredFramesPerSecond = 40
    }

    @IBAction func switchAction(_ sender: UISwitch) {
        let index = sender.tag
        
        switch index {
        case 0:
            Render.Axis.isOn.x = (sender.isOn ? 1: 0)
        case 1:
            Render.Axis.isOn.y = (sender.isOn ? 1: 0)
        case 2:
            Render.Axis.isOn.z = (sender.isOn ? 1: 0)
        case 3:
            Render.Axis.isOn.x = (sender.isOn ? 1: 0)
            Render.Axis.isOn.y = (sender.isOn ? 1: 0)
        case 4:
            Render.Axis.isOn.x = (sender.isOn ? 1: 0)
            Render.Axis.isOn.z = (sender.isOn ? 1: 0)
        case 5:
            Render.Axis.isOn.y = (sender.isOn ? 1: 0)
            Render.Axis.isOn.z = (sender.isOn ? 1: 0)
        case 6:
            Render.Axis.isOn.x = (sender.isOn ? 1: 0)
            Render.Axis.isOn.y = (sender.isOn ? 1: 0)
            Render.Axis.isOn.z = (sender.isOn ? 1: 0)
            
        case 10:
            Render.Axis.isOnForSphere.x = (sender.isOn ? 1: 0)
        case 11:
            Render.Axis.isOnForSphere.y = (sender.isOn ? 1: 0)
        case 12:
            Render.Axis.isOnForSphere.z = (sender.isOn ? 1: 0)
        case 13:
            Render.Axis.isOnForSphere.x = (sender.isOn ? 1: 0)
            Render.Axis.isOnForSphere.y = (sender.isOn ? 1: 0)
        case 14:
            Render.Axis.isOnForSphere.x = (sender.isOn ? 1: 0)
            Render.Axis.isOnForSphere.z = (sender.isOn ? 1: 0)
        case 15:
            Render.Axis.isOnForSphere.y = (sender.isOn ? 1: 0)
            Render.Axis.isOnForSphere.z = (sender.isOn ? 1: 0)
        case 16:
            Render.Axis.isOnForSphere.x = (sender.isOn ? 1: 0)
            Render.Axis.isOnForSphere.y = (sender.isOn ? 1: 0)
            Render.Axis.isOnForSphere.z = (sender.isOn ? 1: 0)
        default:
            break
        }
    }
    
    @IBAction func resetAction(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            Render.Axis.isOn.x = 0
            Render.Axis.isOn.y = 0
            Render.Axis.isOn.z = 0
            
            Render.Axis.eye = simd_float3(0, 0, 0)
        case 1:
            Render.Axis.isOnForSphere.x = 0
            Render.Axis.isOnForSphere.y = 0
            Render.Axis.isOnForSphere.z = 0
            
            Render.Axis.sphere = simd_float3(0, 0, 0)
        default:
            break
        }
    }
    
}

