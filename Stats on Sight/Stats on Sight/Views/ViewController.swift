//
//  ViewController.swift
//  Stats on Sight
//
//  Created by Alex Law on 2020-01-11.
//  Copyright © 2020 Alex Law. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

protocol ViewControllerDelegate: class {
    func retrySearch()
}

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messagePanel: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBOutlet weak var loadingPanel: UIView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var buttonPanel: UIView!
    @IBOutlet weak var buttonIndicator: UIButton!
    
    @IBAction func retryButtonTapped(_ sender: Any) {
        delegate?.retrySearch()
    }
        
    static var instance: ViewController?
    
    weak var delegate: ViewControllerDelegate?
    
    var currentFollowedGameLabelText = ""
    
    var hasLoadedGame = false {
        didSet {
            stopAnimatingLoadingIndicator()
        }
    }
    
    /// An object that detects rectangular shapes in the user's environment
    let rectangleDetector = RectangleDetector()
    
    /// An object that represents an augmented image that exists in the user's environment.
    var gameplayImage: GameplayImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        rectangleDetector.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
//
//        // Create a new scene
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
//
//        // Set the scene to the view
//        sceneView.scene = scene
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ViewController.instance = self
        
        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true
        
        searchForNewImageToTrack()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        // Run the view's session
        sceneView.session.run(configuration)
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    func searchForNewImageToTrack() {
        gameplayImage?.delegate = nil
        gameplayImage = nil
        
        // Restart the session and remove any image anchors that may have been detected previously.
        runWorldTrackingSession(runOptions: [.removeExistingAnchors, .resetTracking])
        
        let messageString = hasLoadedGame ? currentFollowedGameLabelText : "Place Camera at a Live Game"
        showMessage("Place Camera at a Live Game", autoHide: hasLoadedGame)
    }
    
    /// - Tag: ImageTrackingSession
    private func runWorldTrackingSession(runOptions: ARSession.RunOptions = [.removeExistingAnchors]) {
        let configuration = ARWorldTrackingConfiguration();
//        let configuration = ARImageTrackingConfiguration()
        configuration.planeDetection = .vertical
        sceneView.session.run(configuration)
    }
    
    private var messageHideTimer: Timer?
    
    func showMessage(_ message: String, autoHide: Bool = true) {
        DispatchQueue.main.async {
            self.messageLabel.text = message
            self.setMessageHidden(false)
            
            self.messageHideTimer?.invalidate()
            if autoHide {
                self.messageHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { [weak self] _ in
                    self?.setMessageHidden(true)
                })
            }
        }
    }
    
    private func setMessageHidden(_ hide: Bool) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: {
                self.messagePanel.alpha = hide ? 0 : 1
            })
        }
    }
    
    private func setLoadingHidden(_ hide: Bool) {
        loadingPanel.isHidden = hide
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: {
                self.loadingPanel.alpha = hide ? 0 : 1
            })
        }
    }
    
    private func setRetryHidden(_ hide: Bool ) {
        loadingPanel.isHidden = hide
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: {
                self.loadingPanel.alpha = hide ? 0 : 1
            })
        }
    }
}

extension ViewController: ARSCNViewDelegate {
    
    /// - Tag: ImageWasRecognized
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        gameplayImage?.add(anchor, node: node)
        setMessageHidden(true)
    }
    
    /// - Tag: DidUpdateAnchor
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        gameplayImage?.update(anchor)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        if arError.code == .invalidReferenceImage {
            // Restart the experience, as otherwise the AR session remains stopped.
            // There's no benefit in surfacing this error to the user.
            print("Error: The detected rectangle cannot be tracked.")
            searchForNewImageToTrack()
            return
        }
        
        let errorWithInfo = arError as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Use `compactMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that just occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.searchForNewImageToTrack()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

extension ViewController: RectangleDetectorDelegate {
    /// Called when the app recognized a rectangular shape in the user's environment
    func rectangleFound(rectangleContent: CIImage, _ payload: Payload) {
        hasLoadedGame = true
        DispatchQueue.main.async {
            // Ignore detected rectangles if the app is currently tracking an image.
            guard self.gameplayImage == nil else {
                return
            }
            
            guard let referenceImagePixelBuffer = rectangleContent.toPixelBuffer(pixelFormat: kCVPixelFormatType_32BGRA) else {
                print("Error: Could not convert rectangle content into an ARReferenceImage")
                return
            }
            
            let possibleReferenceImage = ARReferenceImage(referenceImagePixelBuffer, orientation: .up, physicalWidth: CGFloat(0.5))
            
            if #available(iOS 13.0, *) {
                possibleReferenceImage.validate{ [weak self] (error) in
                    if let error = error {
                        print("Reference image validation failed: \(error.localizedDescription)")
                        return
                    }
                    
                    // Try tracking the image that lies within the rectangle which the app just detected.
                    guard let newGameplayImage = GameplayImage(rectangleContent, payload) else { return }
                    newGameplayImage.delegate = self
                    self?.gameplayImage = newGameplayImage
                    
                    // Start the session with the newly recognized image.
                    self?.runWorldTrackingSession()
                }
            } else {
                print("Need to be iOS greater than 13.0")
            }
        }
    }
    
    func startAnimatingLoadingIndicator() {
        DispatchQueue.main.async {
            self.loadingIndicator.startAnimating()
            self.setLoadingHidden(false)
        }
    }
    
    func stopAnimatingLoadingIndicator() {
        DispatchQueue.main.async {
            self.loadingIndicator.stopAnimating()
            self.setLoadingHidden(true)
        }
    }
    
    func showMessage(_ string: String, autohide: Bool) {
        if hasLoadedGame {
            currentFollowedGameLabelText = string
        }
        
        DispatchQueue.main.async {
            self.showMessage(string, autoHide: autohide)
        }
    }
    
    func showButton() {
        DispatchQueue.main.async {
            self.setRetryHidden(false)
        }
    }

}

extension ViewController: GameplayImageDelegate {
    func gameplayImageLostTracking(_ gamplayImage: GameplayImage) {
        if !hasLoadedGame {
            print("Lost tracking, looking for new image")
            searchForNewImageToTrack()
        }
    }
    
    func placeNodeInScene(for node: SCNNode) {
        sceneView.scene.rootNode.addChildNode(node)
    }
}

