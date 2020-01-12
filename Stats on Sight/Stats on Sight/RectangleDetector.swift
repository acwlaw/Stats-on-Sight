//
//  RectangleDetector.swift
//  Stats on Sight
//
//  Created by Alex Law on 2020-01-11.
//  Copyright © 2020 Alex Law. All rights reserved.
//

import Foundation
import Vision
import CoreImage

protocol RectangleDetectorDelegate: class {
    func rectangleFound(rectangleContent: CIImage)
}

class RectangleDetector {
    
    private var currentCameraImage: CVPixelBuffer!
    
    private var updateTimer: Timer?
    
    private var updateInterval: TimeInterval = 0.1
    
    private var isBusy = false
    
    weak var delegate: RectangleDetectorDelegate?
    
    init() {
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true, block: { [weak self] _ in
            if let capturedImage = ViewController.instance?.sceneView.session.currentFrame?.capturedImage {
                self?.search(in: capturedImage)
            }
        })
    }
     
    /// Search for rectangles in the camera's pixel buffer if a search is not already running
    /// - Tag: SerializeVision
    private func search(in pixelBuffer: CVPixelBuffer) {
        guard !isBusy else { return }
        isBusy = true
        
        // Remember the current image
        currentCameraImage = pixelBuffer
        
        // Note that the pixel buffer's orientation doesn't change even when the device rotates.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        // Create a Vision rectangle detection request for running on the GPU.
        let request = VNDetectRectanglesRequest { request, error in
            self.completedVisionRequest(request, error: error)
        }
        
        // Look only for one rectangle at a atime
        request.maximumObservations = 1
        
        // Require rectangles to be reasonably large.
        request.minimumConfidence = 0.95
        
        // Ignore rectangles with a too uneven aspect ratio.
        request.minimumAspectRatio = 0.5
        
        // Ignore rectangles that are skewed too much.
        request.quadratureTolerance = 10
        
        // You leverage the `usesCPUOnly` flag of `VNRequest` to decide whether your Vision requests are processed on the CPU or GPU.
        // This sample disables `usesCPUOnly` because rectangle detection isn't very taxing on the GPU. You may benefit by enabling
        // `usesCPUOnly` if your app does a lot of rendering, or runs a complicated neural network.
        request.usesCPUOnly = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            DispatchQueue.global().async {
                do {
                    try handler.perform([request])
                } catch {
                    print("Error: Rectangle detection failed - vision request failed.")
                    
                }
            }
        }
    }
    
    /// Check for a rectangle result.
    /// If one is found, crop the camera image and correct its perspective
    /// - Tag: CropCameraImage
    private func completedVisionRequest(_ request: VNRequest?, error: Error?) {
        defer {
            isBusy = false
        }
        
        // Only proceed if rectangular image was detected.
        guard let rectangle = request?.results?.first as? VNRectangleObservation else {
            guard let error = error else { return }
            print("Error: Rectangle detection failed - Vision request returned an error. \(error.localizedDescription)")
            return
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            print("Error: Rectangle detection failed - Could not create perspective correction filter.")
            return
        }
        
        let width = CGFloat(CVPixelBufferGetWidth(currentCameraImage))
        let height = CGFloat(CVPixelBufferGetHeight(currentCameraImage))
        let topLeft = CGPoint(x: rectangle.topLeft.x * width, y: rectangle.topLeft.y * height)
        let topRight = CGPoint(x: rectangle.topRight.x * width, y: rectangle.topRight.y * height)
        let bottomLeft = CGPoint(x: rectangle.bottomLeft.x * width, y: rectangle.bottomLeft.y * height)
        let bottomRight = CGPoint(x: rectangle.bottomRight.x * width, y: rectangle.bottomRight.y * height)
        
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        let ciImage = CIImage(cvPixelBuffer: currentCameraImage).oriented(.up)
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let perspectiveImage: CIImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else {
            print("Error: Rectangle detection failed - perspective correction filter has no output image.")
            return
        }
        
        delegate?.rectangleFound(rectangleContent: perspectiveImage)
    }
}
