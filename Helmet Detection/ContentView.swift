//
//  ContentView.swift
//  Helmet Detection
//
//  Created by Sambhav Singh on 22/10/24.
//

import SwiftUI
import UIKit
import CoreML
import Vision

struct ContentView: View {
    @StateObject private var detector = HelmetDetector.shared
    @State private var isCameraPresented = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.cyan, .white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let image = capturedImage {
                    GeometryReader { geometry in
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geometry.size.width)
                            
                            // Draw face detection boxes
                            ForEach(detector.faceDetections) { detection in
                                let rect = detection.boundingBox
                                let scaledRect = CGRect(
                                    x: rect.minX * geometry.size.width,
                                    y: (1 - rect.maxY) * geometry.size.height,
                                    width: rect.width * geometry.size.width,
                                    height: rect.height * geometry.size.height
                                )
                                
                                Rectangle()
                                    .path(in: scaledRect)
                                    .stroke(Color.green, lineWidth: 2)
                                
                                Text("\(detection.label): \(Int(detection.confidence * 100))%")
                                    .foregroundColor(.green)
                                    .background(Color.white.opacity(0.7))
                                    .padding(4)
                                    .position(x: scaledRect.minX + (scaledRect.width / 2),
                                              y: scaledRect.minY - 10)
                            }
                            
                            // Draw helmet detection boxes
                            ForEach(detector.detections) { detection in
                                let rect = detection.boundingBox
                                let scaledRect = CGRect(
                                    x: rect.minX * geometry.size.width,
                                    y: (1 - rect.maxY) * geometry.size.height,
                                    width: rect.width * geometry.size.width,
                                    height: rect.height * geometry.size.height
                                )
                                
                                Rectangle()
                                    .path(in: scaledRect)
                                    .stroke(Color.red, lineWidth: 2)
                                
                                Text("\(detection.label): \(Int(detection.confidence * 100))%")
                                    .foregroundColor(.red)
                                    .background(Color.white.opacity(0.7))
                                    .padding(4)
                                    .position(x: scaledRect.minX + (scaledRect.width / 2),
                                              y: scaledRect.minY - 10)
                            }
                        }
                    }
                    .frame(height: 300)
                    
                    // Display detection summary
                    VStack(alignment: .leading, spacing: 10) {
                        if !detector.faceDetections.isEmpty {
                            Text("Face Detections: \(detector.faceDetections.count)")
                                .foregroundColor(.green)
                        }
                        if !detector.detections.isEmpty {
                            Text("Helmet Detections: \(detector.detections.count)")
                                .foregroundColor(.red)
                        }
                        if detector.faceDetections.isEmpty && detector.detections.isEmpty {
                            Text("No detections found")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    if let error = detector.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    Text("No Image Captured")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    isCameraPresented.toggle()
                }) {
                    Text("Photo Library")
                        .font(.title3)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .sheet(isPresented: $isCameraPresented) {
                    ImagePicker(image: $capturedImage) { selectedImage in
                        // Make sure we're on the main thread when updating UI
                        DispatchQueue.main.async {
                            detector.detectObjects(in: selectedImage)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // Preview provider for SwiftUI preview
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
