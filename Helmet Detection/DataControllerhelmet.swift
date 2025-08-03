//
//  DataControllerhelmet.swift
//  Helmet Detection
//
//  Created by Sambhav Singh on 22/10/24.
//

import SwiftUI
import UIKit
import CoreML
import Vision
 
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                // Make sure to call these on the main thread
                DispatchQueue.main.async {
                    self.parent.image = uiImage
                    self.parent.onImageSelected(uiImage)
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

class HelmetDetector: ObservableObject {
    static let shared = HelmetDetector()
    
    @Published var detections: [DetectionResult] = [] // For helmet detections
    @Published var faceDetections: [DetectionResult] = [] // For face detections
    @Published var errorMessage: String?
    @Published var isProcessing: Bool = false
    
    private var helmetModel: VNCoreMLModel?
    private var faceDetectionModel: FaceDetection? // Your specific FaceDetection model
    private let confidenceThreshold: Float = 0.5
    
    init() {
        setupModels()
    }
    
    private func setupModels() {
        do {
            // Load Helmet Detection Model
            if let helmetModelURL = Bundle.main.url(forResource: "new 1", withExtension: "mlmodelc") {
                helmetModel = try VNCoreMLModel(for: MLModel(contentsOf: helmetModelURL))
            }
            
            // Load Face Detection Model
            faceDetectionModel = try FaceDetection()
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error loading models: \(error.localizedDescription)"
            }
        }
    }
    
    func detectObjects(in image: UIImage) {
        // First handle helmet detection
        if let cgImage = image.cgImage {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            
            if let helmetModel = helmetModel {
                let helmetRequest = VNCoreMLRequest(model: helmetModel) { [weak self] request, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Helmet detection error: \(error.localizedDescription)"
                        }
                        return
                    }
                    self?.processHelmetDetections(request)
                }
                helmetRequest.imageCropAndScaleOption = .scaleFit
                
                do {
                    try requestHandler.perform([helmetRequest])
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Helmet detection failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        // Then handle face detection with your specific model
        guard let resizedImage = image.resize(to: CGSize(width: 299, height: 299)),
              let pixelBuffer = resizedImage.toCVPixelBuffer() else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to prepare image for face detection"
            }
            return
        }
        
        do {
            let prediction = try faceDetectionModel?.prediction(image: pixelBuffer)
            
            if let target = prediction?.target,
               let probabilities = prediction?.targetProbability {
                // Find the highest confidence prediction
                if let bestMatch = probabilities[target] {
                    // Create a detection result for the face
                    let faceResult = DetectionResult(
                        label: target,
                        confidence: Float(bestMatch),
                        boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6) // Default face region
                    )
                    
                    DispatchQueue.main.async {
                        self.faceDetections = [faceResult]
                        self.isProcessing = false
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Face detection failed: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    private func processHelmetDetections(_ request: VNRequest) {
        guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }
        
        let detectionResults = observations.compactMap { observation -> DetectionResult? in
            guard let classification = observation.labels.first,
                  classification.confidence > confidenceThreshold else { return nil }
            
            return DetectionResult(
                label: classification.identifier,
                confidence: classification.confidence,
                boundingBox: observation.boundingBox
            )
        }
        
        DispatchQueue.main.async {
            self.detections = detectionResults
        }
    }
}

// Helper to convert UIImage to CVPixelBuffer
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let data = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: data,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        if let cgImage = self.cgImage {
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return pixelBuffer
    }
}



// Helper extension to convert UIImage orientation to CGImagePropertyOrientation
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

extension UIImage {
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
