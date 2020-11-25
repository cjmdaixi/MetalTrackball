//
//  GameViewController.swift
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/24.
//

import UIKit
import MetalKit
import SwiftUI

// Our iOS specific view controller
class ViewController: UIViewController {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var startMatrix: simd_float4x4!
    
    func addSwiftUIView() {
        let swiftUIView = SwiftUIView()
        let hostingController = UIHostingController(rootView: swiftUIView)
        
        /// Add as a child of the current view controller.
        addChild(hostingController)
        
        /// Add the SwiftUI view to the view controller view hierarchy.
        view.addSubview(hostingController.view)
        
        /// Setup the constraints to update the SwiftUI view boundaries.
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            //hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            //hostingController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            view.bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor),
            view.rightAnchor.constraint(equalTo: hostingController.view.rightAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        /// Notify the hosting controller that it has been moved to the current view controller.
        hostingController.didMove(toParent: self)
    }
    @objc func panGestureRecognized(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        
        if gestureRecognizer.state == .began {
            self.startMatrix = renderer.modelMatrix
        }
        // Update the position for the .began, .changed, and .ended states
        if gestureRecognizer.state != .cancelled {
            // Add the X and Y translation to the view's original position.
            let currentPoint = gestureRecognizer.location(in: view)
            let translation = gestureRecognizer.translation(in: view)
            let startPoint = CGPoint(x:currentPoint.x - translation.x, y: currentPoint.y - translation.y)
            
            let rotate = renderer.createRotation(firstPoint: startPoint, nextPoint: currentPoint)
            //let newModelMatrix = simd_mul(simd_float4x4(rotate), self.startMatrix)
            let rotateMatrix = matrix4x4_rotation(radians: rotate.angle, axis: rotate.axis)
            let newModelMatrix = simd_mul(rotateMatrix, self.startMatrix)
            renderer.setModelMatrix(newModelMatrix)
        }
        else{
            
        }
    }
    
    @objc func tapGestureRecognized(_ tapGestureRecognizer: UITapGestureRecognizer) {
        //print("tap \(tapGestureRecognizer.state.rawValue)")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ViewController.panGestureRecognized(_:)))
        view.addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.tapGestureRecognized(_:)))
        view.addGestureRecognizer(tapGestureRecognizer)
        
        guard let mtkView = view as? MTKView else {
            print("View of Gameview controller is not an MTKView")
            return
        }
        
        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }
        
        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.white
        
        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }
        
        renderer = newRenderer
        
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        mtkView.delegate = renderer
        
        addSwiftUIView()
    }
}
