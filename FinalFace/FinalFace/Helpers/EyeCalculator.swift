//
//  EyeCalculator.swift
//  FinalFace
//
//  Created by Lars Knutsson on 2018-05-14.
//  Copyright © 2018 jens andreassen. All rights reserved.
//

import Foundation

import ARKit
import SceneKit

class Angle3D: NSObject {
    func angle3D(objectAnchor: ARAnchor, cameraAnchor: ARFrame) -> Float {
        let transformObject = objectAnchor.transform
        let transformCamera = cameraAnchor.camera.transform
        
        let dotProduct = (transformObject.columns.3.x * transformCamera.columns.3.x) +
            (transformObject.columns.3.y * transformCamera.columns.3.y) +
            (transformObject.columns.3.z * transformCamera.columns.3.z)
        let objectLength = sqrt(pow(transformObject.columns.3.x, 2) + pow(transformObject.columns.3.y, 2) + pow(transformObject.columns.3.z, 2))
        let cameraLength = sqrt(pow(transformCamera.columns.3.x, 2) + pow(transformCamera.columns.3.y, 2) + pow(transformCamera.columns.3.z, 2))
        let angle = acos(dotProduct/(objectLength * cameraLength))*(180/Float.pi)
        
        return angle
    }
}
