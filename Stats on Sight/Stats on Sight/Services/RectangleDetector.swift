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
    func rectangleFound(rectangleContent: CIImage, _ payload: Payload)
    func startAnimatingLoadingIndicator()
    func stopAnimatingLoadingIndicator()
    func showMessage(_ string: String, autohide: Bool)
    func showButton()
}

class RectangleDetector {
    
    private var currentCameraImage: CVPixelBuffer!
    
    private var updateTimer: Timer?
    
    private var updateInterval: TimeInterval = 0.1
    
    private var isBusy = false
    
    private var hasFoundPotentialImage = false
    
    weak var delegate: RectangleDetectorDelegate?
    
    init() {
        initiateSearch()
    }
    
    func initiateSearch() {
        ViewController.instance?.delegate = self
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: self.updateInterval, repeats: true, block: { [weak self] _ in
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
        request.minimumConfidence = 0.90
        
        // Ignore rectangles with a too uneven aspect ratio.
        request.minimumAspectRatio = 0.50
        request.maximumAspectRatio = 0.80
        
        // Ignore rectangles that are skewed too much.
        request.quadratureTolerance = 10
        
        // You leverage the `usesCPUOnly` flag of `VNRequest` to decide whether your Vision requests are processed on the CPU or GPU.
        // This sample disables `usesCPUOnly` because rectangle detection isn't very taxing on the GPU. You may benefit by enabling
        // `usesCPUOnly` if your app does a lot of rendering, or runs a complicated neural network.
        request.usesCPUOnly = false
        
     
        DispatchQueue.global().async {
            do {
                try handler.perform([request])
            } catch {
                print("Error: Rectangle detection failed - vision request failed.")
                
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
    
        
        if !hasFoundPotentialImage {
            hasFoundPotentialImage = true
            analyzeImage(for: perspectiveImage)
        }
    }
    
    func analyzeImage(for image: CIImage) {
        DispatchQueue.main.async {
            self.delegate?.startAnimatingLoadingIndicator()
        }
        
        guard let url = URL(string: "http://stats-on-sight.appspot.com/upload") else {
            print("Unable to create a URL from given string")
            return
        }
        
        let uiImage = image.convertToUIImage()
        
        guard let imageData = uiImage.jpegData(compressionQuality: 1) else {
            print("Unable to get image data")
            return
        }
        
        let uniqueFileName = "file" + UUID().uuidString + ".jpg"
        
        sendFile(url: url, fileName: uniqueFileName, data: imageData) { (data, response, error) in
            self.delegate?.stopAnimatingLoadingIndicator()
            
            guard let data = data else {
                self.delegate?.showButton()
                self.hasFoundPotentialImage = false
                print("No data")
                return
            }
            
            print(String(data: data, encoding: String.Encoding.utf8))
                
            guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                self.delegate?.showButton()
                self.hasFoundPotentialImage = false
                print("Unable to decode payload")
                return
            }
            
            print("RECEIVED PAYLOAD")
            
            self.delegate?.showMessage("Now following \(payload.homeTeam.name) vs. \(payload.awayTeam.name)", autohide: true)
            self.delegate?.rectangleFound(rectangleContent: image, payload)
        }
    }
    
    func sendFile(url: URL, fileName: String, data: Data, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {

        var request1: URLRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)

        request1.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        let fullData = photoDataToFormData(data: data, boundary: boundary, fileName: fileName)

        request1.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")

        // REQUIRED!
        request1.setValue(String(fullData.count), forHTTPHeaderField: "Content-Length")

        request1.httpBody = fullData
        request1.httpShouldHandleCookies = true
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        
        let task = session.dataTask(with: request1, completionHandler: completionHandler)
        
        task.resume()
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

extension RectangleDetector: ViewControllerDelegate {
    func retrySearch() {
        print("Search is reattempted")
        initiateSearch()
    }
}
