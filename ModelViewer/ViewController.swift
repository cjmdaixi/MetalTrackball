//
//  GameViewController.swift
//  ModelViewer
//
//  Created by 陈锦明 on 2020/11/24.
//

import UIKit
import MetalKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass

class PanRecognizerWithInitialTouch : UIPanGestureRecognizer {
  var initialTouchLocation: CGPoint!
    
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    initialTouchLocation = touches.first!.location(in: view)
  }
}

// Our iOS specific view controller
class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var startRotationMatrix: simd_float4x4!
    var startModelMatrix: simd_float4x4!
    var startPoint: CGPoint!
    var startDistance: Float!
    var touchesDistance: Float!
    var globalVariables : GlobalVariables!
    
    func addSwiftUIView() {
        let swiftUIView = SwiftUIView().environmentObject(self.globalVariables)
        
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
    @objc func panGestureRecognized(_ gestureRecognizer: PanRecognizerWithInitialTouch) {
        guard gestureRecognizer.view != nil else {return}
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        
        if gestureRecognizer.state == .began {
            self.startRotationMatrix = renderer.camera.rotationMatrix
            self.startPoint = gestureRecognizer.initialTouchLocation
        }
        // Update the position for the .began, .changed, and .ended states
        if gestureRecognizer.state != .cancelled {
            let currentPoint = gestureRecognizer.location(in: view)
            let rotate = renderer.createRotation(firstPoint: self.startPoint, nextPoint: currentPoint)
            let rotateMatrix = matrix4x4_rotation(radians: rotate.angle, axis: rotate.axis)
            let newRotationMatrix = simd_mul(rotateMatrix, self.startRotationMatrix)
            renderer.camera.rotationMatrix = newRotationMatrix
        }
    }
    
    @objc func translateGestureRecognized(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        
        if gestureRecognizer.state == .began {
            self.startModelMatrix = renderer.modelMatrix
            self.startPoint = gestureRecognizer.location(in: view)
        }
        // Update the position for the .began, .changed, and .ended states
        if gestureRecognizer.state != .cancelled {
            if gestureRecognizer.numberOfTouches < 2{
                return
            }
            
            let currentPoint = gestureRecognizer.location(in: view)
            
            let trans = renderer.createTranslation(firstPoint: self.startPoint, nextPoint: currentPoint)
            let transMatrix = matrix4x4_translation(trans.x, trans.y, trans.z)
            let newModelMatrix = simd_mul(transMatrix, self.startModelMatrix)
            renderer.modelMatrix = newModelMatrix
            
        }
    }
    
    @objc func pinchGestureRecognized(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        
        if gestureRecognizer.state == .began {
            self.startDistance = renderer.camera.distance
        }
        // Update the position for the .began, .changed, and .ended states
        if gestureRecognizer.state != .cancelled {
            if gestureRecognizer.numberOfTouches < 2{
                return
            }
            
            let scale:Float = Float(gestureRecognizer.scale)
            renderer.camera.distance = (Float(1) / scale) * self.startDistance
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer)
            -> Bool {
       // If the gesture recognizer's view isn't one of the squares, do not
       // allow simultaneous recognition.
        guard gestureRecognizer.view != nil else {return false}
        guard otherGestureRecognizer.view != nil else {return false}
        
       // If the gesture recognizers are on diferent views, do not allow
       // simultaneous recognition.
       if gestureRecognizer.view != otherGestureRecognizer.view {
          return false
       }
       // If either gesture recognizer is a long press, do not allow
       // simultaneous recognition.
       if gestureRecognizer is UILongPressGestureRecognizer ||
              otherGestureRecognizer is UILongPressGestureRecognizer {
          return false
       }
        if gestureRecognizer is PanRecognizerWithInitialTouch ||
               otherGestureRecognizer is PanRecognizerWithInitialTouch {
           return false
        }
     
       return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let panGestureRecognizer = PanRecognizerWithInitialTouch(target: self, action: #selector(ViewController.panGestureRecognized(_:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGestureRecognizer)
        
        let translateGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ViewController.translateGestureRecognized(_:)))
        translateGestureRecognizer.minimumNumberOfTouches = 2
        translateGestureRecognizer.maximumNumberOfTouches = 2
        translateGestureRecognizer.delegate = self
        view.addGestureRecognizer(translateGestureRecognizer)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ViewController.pinchGestureRecognized(_:)))
        view.addGestureRecognizer(pinchGestureRecognizer)
        
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
        
        globalVariables = GlobalVariables()
        globalVariables.renderer = newRenderer
        
        addSwiftUIView()
    }
}
