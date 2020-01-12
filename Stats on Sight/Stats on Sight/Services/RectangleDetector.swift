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
import UIKit

protocol RectangleDetectorDelegate: class {
    func rectangleFound(rectangleContent: CIImage)
    func startAnimatingLoadingIndicator()
    func stopAnimatingLoadingIndicator()
    func showMessage(_ string: String, autohide: Bool)
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
        
        analyzeImage(for: perspectiveImage)
        delegate?.rectangleFound(rectangleContent: perspectiveImage)
    }
    
    func analyzeImage(for image: CIImage) {
        DispatchQueue.main.async {
            self.delegate?.startAnimatingLoadingIndicator()
        }
        
        guard let url = URL(string: "http://stats-on-sight.appspot.com/upload") else {
            print("Unable to create a URL from given string")
            return
        }
        
        guard let uiImage = image.convertToUIImage().rotate(radians: .pi/2),
            let imageData = uiImage.jpegData(compressionQuality: 1) else {
            print("Unable to get image data")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        
        sendFile(url: url, fileName: "file.jpg", data: imageData) { (response, data, error) in
            self.delegate?.stopAnimatingLoadingIndicator()
            
            guard let data = data, let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                print("Unable to decode payload")
                return
            }
            
            self.delegate?.showMessage("Now following \(payload.homeTeam.name) vs. \(payload.awayTeam.name)", autohide: true)
        }
    }
    
    func sendFile(url: URL, fileName: String, data: Data, completionHandler: @escaping (URLResponse?, Data?, Error?) -> Void) {

        let request1: NSMutableURLRequest = NSMutableURLRequest(url: url)

        request1.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        let fullData = photoDataToFormData(data: data, boundary: boundary, fileName: fileName)

        request1.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")

        // REQUIRED!
        request1.setValue(String(fullData.count), forHTTPHeaderField: "Content-Length")

        request1.httpBody = fullData
        request1.httpShouldHandleCookies = false

        let queue: OperationQueue = OperationQueue()

        NSURLConnection.sendAsynchronousRequest(request1 as URLRequest, queue: queue, completionHandler: completionHandler)
    }
    
    func photoDataToFormData(data: Data, boundary: String, fileName: String) -> Data {
        let fullData = NSMutableData()

        // 1 - Boundary should start with --
        let lineOne = "--" + boundary + "\r\n"
        fullData.append(lineOne.data(
            using: String.Encoding.utf8,
            allowLossyConversion: false)!)

        // 2
        let lineTwo = "Content-Disposition: form-data; name=\"file\"; filename=\"" + fileName + "\"\r\n"
        NSLog(lineTwo)
        fullData.append(lineTwo.data(
            using: String.Encoding.utf8,
            allowLossyConversion: false)!)

        // 3
        let lineThree = "Content-Type: image/jpg\r\n\r\n"
        fullData.append(lineThree.data(
            using: String.Encoding.utf8,
            allowLossyConversion: false)!)

        // 4
        fullData.append(data as Data)

        // 5
        let lineFive = "\r\n"
        fullData.append(lineFive.data(
            using: String.Encoding.utf8,
            allowLossyConversion: false)!)

        // 6 - The end. Notice -- at the start and at the end
        let lineSix = "--" + boundary + "--\r\n"
        fullData.append(lineSix.data(
            using: String.Encoding.utf8,
            allowLossyConversion: false)!)

        return fullData as Data
    }
}
