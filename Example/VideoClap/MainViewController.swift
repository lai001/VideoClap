//
//  MainViewController.swift
//  VideoClap_Example
//
//  Created by lai001 on 2021/2/22.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import Photos

class MainViewController: UITableViewController {

    lazy var controllers: [UIViewController.Type] = {
        return [ViewController.self,
                TestTimeScaleView.self,
                TestTrackView.self,
                MetalViewController.self,
                TestTrackView2.self,
                MetalImageViewController.self,
                LottieToGif.self,
                MetalOfflineRenderTestController.self,
                TestParticle.self]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        PHPhotoLibrary.requestAuthorization { (_) in
            
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return controllers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = String(describing: controllers[indexPath.item])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = controllers[indexPath.item]
        navigationController?.pushViewController(controller.init(), animated: true)
    }

}
