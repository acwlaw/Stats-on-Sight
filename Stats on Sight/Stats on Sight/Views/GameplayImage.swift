//
//  GameplayImage.swift
//  Stats on Sight
//
//  Created by Alex Law on 2020-01-11.
//  Copyright © 2020 Alex Law. All rights reserved.
//

import Foundation
import ARKit
import CoreML

protocol GameplayImageDelegate: class {
    func gameplayImageLostTracking(_ gamplayImage: GameplayImage)
    func placeNodeInScene(for node: SCNNode)
}

/// - Tag: GameplayImage
class GameplayImage {
    
    let referenceImage: ARReferenceImage
    
    /// A handle to the anchor ARKit assigned the tracked image.
    private(set) var anchor: ARImageAnchor?
    
    /// Stores  a reference to the Core ML output image.
    private var modelOutputImage: CVPixelBuffer?
    
    private var fadeBetweenStyles = true
    
    /// A timer that affects a grace period before checking for a new rectangular shape in the user's environment.
    private var failedTrackingTimeout: Timer?
    
    /// The timeout in seconds after which the `imageTrackingLost` delegate is called.
    private var timeout: TimeInterval = 1.0
    
    /// Delegate for when image tracking fails.
    weak var delegate: GameplayImageDelegate?
    
    init?(_ image: CIImage, referenceImage: ARReferenceImage) {
        self.referenceImage = referenceImage
        resetImageTrackingTimeout()
    }
    
    /// Displays the gamePlay image using the anchor and node provided by ARKit
    /// - Tag: AddVisualizationNode
    func add(_ anchor: ARAnchor, node: SCNNode) {
        if let imageAnchor = anchor as? ARImageAnchor, imageAnchor.referenceImage == referenceImage {
            self.anchor = imageAnchor
            
            
            // Start the image tracking timeout.
            resetImageTrackingTimeout()
            let plane = SCNPlane(width: CGFloat(referenceImage.physicalSize.width),
                                     height: CGFloat(referenceImage.physicalSize.height))
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.simdTransform = simd_float4x4(SCNMatrix4MakeTranslation(0, 0, -0.355))
            planeNode.eulerAngles.x = -.pi/2
            
            let text = SCNText(string: "5 - 1", extrusionDepth: 0.1)
            text.font = UIFont(name: "Arial", size: 20)
            text.isWrapped = true
            let textNode = SCNNode(geometry: text)
            
            text.containerFrame = CGRect(origin: .zero, size: CGSize(width: 200.0, height: 100.0))
            textNode.scale = SCNVector3Make(0.01, 0.01, 0.01)
            
            
            textNode.eulerAngles.x = -.pi/2
//            textNode.simdTransform = simd_float4x4(SCNMatrix4MakeTranslation(0, 0, -0.355))
//            textNode.simdTransform = simd_float4x4(SCNMatrix4MakeTranslation(0, 0, 0))
            
            let (min, max) = textNode.boundingBox
            
            let dx = min.x + 0.5 * (max.x - min.x)
            let dy = min.y + 0.5 * (max.y - min.y) - 25
            let dz = min.z + 0.5 * (max.z - min.z)
            textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
            
            
            
            
//            let path = UIBezierPath()
//            path.move(to: CGPoint(x: 0.1, y: 0.1))
//            path.addLine(to: CGPoint(x: 0.1, y: -0.1))
//            path.addLine(to: CGPoint(x: -0.1, y: -0.1))
//            path.addLine(to: CGPoint(x: -0.1, y: 0.1))
//            path.close()
//
//            let shape = SCNShape(path: path, extrusionDepth: 0.2)
//            let color = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
//            shape.firstMaterial?.diffuse.contents = color
//            shape.chamferRadius = 0.1
//
//            let squareNode = SCNNode(geometry: shape)
//            squareNode.position.z = -1
            
//            node.addChildNode(planeNode)
            node.addChildNode(textNode)
            
//            delegate?.placeNodeInScene(for: squareNode)
            
            
//            // Add the node that displays the altered image to the node graph.
//            node.addChildNode(visualizationNode)
//
//            // If altering the first image completed before the
//            //  anchor was added, display that image now.
//            if let createdImage = modelOutputImage {
//                visualizationNode.display(createdImage)
//            }
        } else {
            print("FAIL")
        }
    }
    
    /**
     If an image the app was tracking is no longer tracked for a given amount of time, invalidate
     the current image tracking session. This, in turn, enables Vision to start looking for a new
     rectangluar shape in the camera feed.
     - Tag: AnchorWasUpdated
     */
    func update(_ anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor, self.anchor == anchor {
            self.anchor = imageAnchor
            // Reset the timeout if the app is still tracking an image.
            if imageAnchor.isTracked {
                resetImageTrackingTimeout()
            }
        }
    }
    
    /// Prevents the image tracking timeout from expiring.
    private func resetImageTrackingTimeout() {
        failedTrackingTimeout?.invalidate()
        failedTrackingTimeout = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            if let strongSelf = self {
                self?.delegate?.gameplayImageLostTracking(strongSelf)
            }
        }
    }
    
}
