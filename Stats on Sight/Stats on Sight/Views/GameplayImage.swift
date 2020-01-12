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

enum Position {
    case above
    case right
    case left
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

            // Top Label
            let topText = SCNText(string: "5 - 1", extrusionDepth: 0.1)
            topText.font = UIFont(name: "System", size: 20)
            topText.isWrapped = true
            var topTextNode = SCNNode(geometry: topText)
            
            topText.containerFrame = CGRect(origin: .zero, size: CGSize(width: 200.0, height: 100.0))
            topTextNode.scale = SCNVector3Make(0.01, 0.01, 0.01)
            topTextNode.eulerAngles.x = -.pi/2
            
            setNodePivot(for: &topTextNode, position: .above)
            
            // Right Label
            let rightText = SCNText(string: "13 14 15 16 17", extrusionDepth: 0.1)
            rightText.font = UIFont(name: "System", size: 5.0)
            rightText.isWrapped = true
            var rightTextNode = SCNNode(geometry: rightText)
            
            rightText.containerFrame = CGRect(origin: .zero, size: CGSize(width: 15.0, height: 150.0))
            rightTextNode.scale = SCNVector3Make(0.01, 0.01, 0.01)
            rightTextNode.eulerAngles.x = -.pi/2
            
            setNodePivot(for: &rightTextNode, position: .right)
                    
            // Left Label
            let leftText = SCNText(string: "31 41 51 61 71", extrusionDepth: 0.1)
            leftText.font = UIFont(name: "System", size: 5.0)
            leftText.isWrapped = true
            var leftTextNode = SCNNode(geometry: leftText)
            
            leftText.containerFrame = CGRect(origin: .zero, size: CGSize(width: 15.0, height: 150.0))
            leftTextNode.scale = SCNVector3Make(0.01, 0.01, 0.01)
            leftTextNode.eulerAngles.x = -.pi/2
            
            setNodePivot(for: &leftTextNode, position: .left)
            
            node.addChildNode(topTextNode)
            node.addChildNode(rightTextNode)
            node.addChildNode(leftTextNode)
        } else {
            print("FAIL")
        }
    }
    
    func setNodePivot(for node: inout SCNNode, position: Position) {
        let (min, max) = node.boundingBox
        
        var dx = min.x + 0.5 * (max.x - min.x)
        var dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        
        switch position {
        case .above:
            dy = min.y + 0.5 * (max.y - min.y) - 25
        case .right:
            dx = min.x + 0.5 * (max.x - min.x) - 35
        case .left:
            dx = min.x + 0.5 * (max.x - min.x) + 35
        }
        
        node.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
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
