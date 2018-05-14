//
//  ViewController.swift
//  FinalFace
//
//  Created by jens andreassen on 2018-05-13.
//  Copyright © 2018 jens andreassen. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import AVFoundation
import CoreMedia


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView! //Detta eller en view framfor??
    
    
    
    
    let yolo = YOLO()
    
    var videoCapture: VideoCapture!
    var request: VNCoreMLRequest!
    var boundingBoxes = [BoundingBox]()
    let semaphore = DispatchSemaphore(value: 2) //<----------Beh;vs denna??
    
    var stabilizeStarter = 0
    var stabilizeWorth = 16
    var stabilizeFrames = 4  //<-------------------------  Prova lite olika plz
    var rectangles: [CGRect] = []
    
    private var midPos = (x: 0.0, y: 0.0)
    private var screenWidth: Double?
    private var screenHeight: Double?
    
    let dollLayer = CALayer()
    let dollMathiasImg = UIImage(named: "mathias_head")
    let leftEyeLayer = CALayer()
    let dollMathiasLeftEyeImg = UIImage(named: "mathias_eyes")
    let rightEyeLayer = CALayer()
    let dollMathiasRightEyeImg = UIImage(named: "mathias_eyes")
    let eyeWhiteLayer = CALayer()
    let dollEyeWhiteImg = UIImage(named: "eyeWhiteBackground")
    let dollEyesLayer = CALayer()
    let dollEyesImg = UIImage(named: "two_eyes")
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        
        
        checkCenter()
        setUpBoundingBoxes()
        setUpVision()
        setUpCamera()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // HIT TEST : REAL WORLD
        // Get Screen Centre
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
//            // Create 3D Text
//            let node : SCNNode =
//            sceneView.scene.rootNode.addChildNode(node)
//            node.position = worldCoord
        }
    }
    
    
    //////////////////////////////////////////////////////////////////////////
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        resizePreviewLayer()
    }
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        // Vision will automatically resize the input image.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
            
            let boundingBoxes = yolo.computeBoundingBoxes(features: features)
            showOnMainThread(boundingBoxes)
        }
    }
    
    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction]) {
        DispatchQueue.main.async {
            self.show(predictions: boundingBoxes)
            self.semaphore.signal()
        }
    }
    
    func show(predictions: [YOLO.Prediction]) {
        for i in 0..<boundingBoxes.count {
            if i < predictions.count {
                let prediction = predictions[i]
                
                // The predicted bounding box is in the coordinate space of the input
                // image, which is a square image of 416x416 pixels. We want to show it
                // on the video preview, which is as wide as the screen and has a 4:3
                // aspect ratio. The video preview also may be letterboxed at the top
                // and bottom.
                let width = view.bounds.width
                let height = width * 4 / 3
                let scaleX = width / CGFloat(YOLO.inputWidth)
                let scaleY = height / CGFloat(YOLO.inputHeight)
                let top = (view.bounds.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                rect = stabilizeRect(rect: rect)
                
                let anchor: ARAnchor = (sceneView.hitTest(CGPoint(
                    x: rect.minX+(rect.width/2),
                    y: rect.minY+(rect.height/3)),
                    types: .featurePoint).first?.anchor)!
                
                //Skicka anchor och fa resultat
                
                
                dollLayer.frame = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height * 0.6)
                dollLayer.contents = dollMathiasImg?.cgImage
                
                let leftEyePos = eyePosition(imageX: Double(rect.origin.x + dollLayer.frame.width * 0.16),
                                             imageY: Double(rect.origin.y + dollLayer.frame.height * 0.51),
                                             eyeRadius: Double(rect.size.width * 0.14))
                
                leftEyeLayer.frame = CGRect(x: leftEyePos.x, y: leftEyePos.y,
                                            width: Double(rect.size.width * 0.14), height: Double(dollLayer.frame.height * 0.219))
                leftEyeLayer.contents = dollMathiasLeftEyeImg?.cgImage
                
                let rightEyePos = eyePosition(imageX: Double(rect.origin.x + dollLayer.frame.width * 0.61),
                                              imageY: Double(rect.origin.y + dollLayer.frame.height * 0.51),
                                              eyeRadius: Double(rect.size.width * 0.14))
                rightEyeLayer.frame = CGRect(x: rightEyePos.x,
                                             y: rightEyePos.y,
                                             width: Double(rect.size.width * 0.14), height: Double(dollLayer.frame.height * 0.219))
                rightEyeLayer.contents = dollMathiasRightEyeImg?.cgImage
                
                eyeWhiteLayer.frame = CGRect(x: Double(rect.origin.x + dollLayer.frame.width * 0.1),
                                             y: Double(rect.origin.y + dollLayer.frame.height * 0.45),
                                             width: Double(dollLayer.frame.width * 0.8),
                                             height: Double(dollLayer.frame.height * 0.3))
                eyeWhiteLayer.contents = dollEyeWhiteImg?.cgImage
                
                sceneView?.layer.addSublayer(eyeWhiteLayer)
                sceneView?.layer.addSublayer(leftEyeLayer)
                sceneView?.layer.addSublayer(rightEyeLayer)
                sceneView?.layer.addSublayer(dollLayer)

                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = UIColor.red
                
                boundingBoxes[i].show(frame: rect, label: label, color: color)
            } else {
                boundingBoxes[i].hide()
                dollLayer.removeFromSuperlayer()
                eyeWhiteLayer.removeFromSuperlayer()
                leftEyeLayer.removeFromSuperlayer()
                rightEyeLayer.removeFromSuperlayer()
            }
        }
    }
    func stabilizeRect(rect: CGRect) -> CGRect {
        
        if stabilizeStarter < stabilizeFrames {
            stabilizeStarter += 1
            rectangles.removeAll()
            for _ in 1...stabilizeFrames{
                rectangles.append(rect)
            }
        } else {
            rectangles.remove(at: 0)
            rectangles.append(rect)
        }
        
        var xValue: CGFloat = 0
        var yValue: CGFloat = 0
        var widthValue: CGFloat = 0
        var heightValue: CGFloat = 0
        
        for rect in rectangles {
            xValue += rect.origin.x
            yValue += rect.origin.y
            widthValue += rect.width
            heightValue += rect.height
        }
        for _ in 1...stabilizeWorth{
            xValue += rect.origin.x
            yValue += rect.origin.y
            widthValue += rect.width
            heightValue += rect.height
        }
        
        var stabilizedRect: CGRect = CGRect(x: xValue/CGFloat(stabilizeFrames+stabilizeWorth),
                                            y: yValue/CGFloat(stabilizeFrames+stabilizeWorth),
                                            width: widthValue/CGFloat(stabilizeFrames+stabilizeWorth),
                                            height: heightValue/CGFloat(stabilizeFrames+stabilizeWorth))
        return stabilizedRect
    }
    
    func eyePosition(imageX: Double, imageY: Double, eyeRadius: Double) -> (x: Double, y: Double) {
        let degree: Double?
        
        if imageX == midPos.x {
            degree = atan2(imageY-midPos.y, imageX-midPos.x) * (180.0 / Double.pi)
        } else {
            degree = atan2(imageY-midPos.y, imageX-midPos.x) * (180.0 / Double.pi)
        }
        
        var vx = imageX - midPos.x
        var vy = imageY - midPos.y
        var distToEdge:Double?
        let mag = sqrt(pow(vx, 2) + pow(vy, 2))
        if imageX == midPos.x || (imageX >= midPos.x-40 && imageX <= midPos.x+40){
            distToEdge = midPos.y
        } else {
            distToEdge = (screenWidth!/2)/(cos(degree!.degreesToRadians))
        }
        
        let pDist = (mag / distToEdge!) * eyeRadius
        
        if mag == 0 {
            vx = 0
            vy = 0
        } else {
            vx /= mag
            vy /= mag
        }
        
        var px: Double?
        var py: Double?
        if imageX == midPos.x || (imageX >= midPos.x-40 && imageX <= midPos.x+40) {
            px = midPos.x + vx * (mag + -pDist)
            py = midPos.y + vy * (mag + -pDist)
        } else if imageX > midPos.x{
            px = midPos.x + vx * (mag + -pDist)
            py = midPos.y + vy * (mag + -pDist)
        } else if imageX < midPos.x{
            px = midPos.x + vx * (mag + pDist)
            py = midPos.y + vy * (mag + pDist)
        }
        
        return (x: px!, y: py!)
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = sceneView.bounds
    }
    
    func checkCenter(){
        screenWidth = Double(UIScreen.main.bounds.width)
        screenHeight = Double(UIScreen.main.bounds.height)
        midPos.x = Double(screenWidth!/2)
        midPos.y = Double(screenHeight!/2)
    }
    
    func setUpBoundingBoxes() {
        for _ in 0..<YOLO.maxBoundingBoxes {
            boundingBoxes.append(BoundingBox())
        }
    }
    
    func setUpVision() {
        guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
            print("Error: could not create Vision model")
            return
        }
        request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 50
        videoCapture.setUp(sessionPreset: AVCaptureSession.Preset.vga640x480) { success in
            if success {
                // Add the video preview into the UI.
                //if let previewLayer = self.videoCapture.previewLayer {
                //    self.sceneView.layer.addSublayer(previewLayer)
                //    self.resizePreviewLayer()
                //}
                
                // Add the bounding box layers to the UI, on top of the video preview.
                for box in self.boundingBoxes {
                    box.addToLayer(self.sceneView.layer)
                }
                
                // Once everything is set up, we can start capturing live video.
                self.videoCapture.start()
            }
        }
    }
}
extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
}
extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {

        semaphore.wait()
        
        if let pixelBuffer = pixelBuffer {
            
            DispatchQueue.global().async {
                self.predictUsingVision(pixelBuffer: pixelBuffer)
            }
        }
    }
}
