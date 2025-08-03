//
//  DataModel.swift
//  Helmet Detection
//
//  Created by Sambhav Singh on 22/10/24.
//

import Foundation
import CoreGraphics

struct DetectionResult: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
