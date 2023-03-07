/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import RealityKit
import ARKit
import AVFoundation

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
//    @IBOutlet weak var hideMeshButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
//    @IBOutlet weak var planeDetectionButton: UIButton!
    
    let coachingOverlay = ARCoachingOverlayView()
    
    // Cache for 3D text geometries representing the classification values.
    var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]
  
     // Define a variable to keep track of the screen brightness
    var originalBrightness: CGFloat = UIScreen.main.brightness

    var scanTimer = Timer()
    var processTimer = Timer()
    
    let scanRefreshInterval: Double = 1.0
    let processRefreshInterval: Double = 1.5
    
    let synthesizer = AVSpeechSynthesizer()
    
    var pointQueue = Queue<DataPoint>()
    
    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification

        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        // Enable plane detection
//        configuration.planeDetection = [.horizontal, .vertical]
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
      
        // Create a button and add it to the view
        let button = UIButton(type: .system)
        button.setTitle("Dim Screen", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.addTarget(self, action: #selector(dimScreen(_:)), for: .touchUpInside)
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.accessibilityLabel = "Dim Screen Button"
        button.backgroundColor = .blue
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        view.addSubview(button)

        // Set the button's constraints to position it in the lower left of the screen
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32)
        ])
    }
    
    @objc func dimScreen(_ sender: UIButton) {
        // If the screen brightness is not already dimmed, dim it
        if UIScreen.main.brightness != 0 {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0
            sender.setTitle("Undim Screen", for: .normal)
            sender.accessibilityLabel = "Undim Screen Button"
        }
        // If the screen brightness is already dimmed, undim it
        else {
            UIScreen.main.brightness = originalBrightness
            sender.setTitle("Dim Screen", for: .normal)
            sender.accessibilityLabel = "Dim Screen Button"
        }
   }
        
        self.scanTimer = Timer.scheduledTimer(withTimeInterval: scanRefreshInterval, repeats: true, block: { _ in
            self.simulateTaps()
            })
        
        self.processTimer = Timer.scheduledTimer(withTimeInterval: processRefreshInterval, repeats: true, block: { _ in
            self.processData()
            })
    }
    
    func simulateTaps() {
        var pointList: [DataPoint] = []
        pointList.append(DataPoint(cgPoint: CGPointMake(50, 100)))
        pointList.append(DataPoint(cgPoint: CGPointMake(200, 100)))
        pointList.append(DataPoint(cgPoint: CGPointMake(350, 100)))
        pointList.append(DataPoint(cgPoint: CGPointMake(50, 350)))
        pointList.append(DataPoint(cgPoint: CGPointMake(200, 350)))
        pointList.append(DataPoint(cgPoint: CGPointMake(350, 350)))
        pointList.append(DataPoint(cgPoint: CGPointMake(50, 500)))
        pointList.append(DataPoint(cgPoint: CGPointMake(200, 500)))
        pointList.append(DataPoint(cgPoint: CGPointMake(350, 500)))
        pointList.append(DataPoint(cgPoint: CGPointMake(50, 650)))
        pointList.append(DataPoint(cgPoint: CGPointMake(200, 650)))
        pointList.append(DataPoint(cgPoint: CGPointMake(350, 650)))
        for var point in pointList {
            let result = measureAndIdentify(dataPoint: point)
            point.distance = result.distance
            point.classification = result.classification
        }
        
    }
    
    func processData() {
        if (pointQueue.isEmpty) {
            return
        }
        print("🟢🟢🟢🟢🟢🟢🟢🟢🟢" + String(pointQueue.size))
        
        let pointList: [DataPoint] = pointQueue.dequeueAll()
//        for _ in 0...pointCounter-1 {
//            pointList.append(pointQueue.dequeue() ?? DataPoint(distance: 100))
//        }
        print("🔴🔴🔴🔴🔴🔴🔴🔴🔴" + String(pointQueue.size))
        var closestPoint: DataPoint = DataPoint(distance: 100)
        
        // find closest point
        for point in pointList {
            if point.distance < closestPoint.distance {
                closestPoint = point
            }
        }
        
        if closestPoint.distance >= 6.0 {
            return
        }
        let distance = Int(closestPoint.distance)
        
        if closestPoint.classification == "Floor" {
            return
        }
        
        var position = ""
        let xCoord = closestPoint.cgPoint.x
        if xCoord == 50 {
            position = "left"
        } else if xCoord == 200 {
            position = "ahead"
        } else {
            position = "right"
        }
        
        let utterance = AVSpeechUtterance(string: (closestPoint.classification + String(distance)) + "feet" + position)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.65 // Adjust the speech rate
        utterance.pitchMultiplier = 1.2 // Adjust the pitch of the voice
        utterance.volume = 1.0 // Set the volume of the speech
        synthesizer.speak(utterance)
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    /// Places virtual-text of the classification at the touch-location's real-world intersection with a mesh.
    /// Note - because classification of the tapped-mesh is retrieved asynchronously, we visualize the intersection
    /// point immediately to give instant visual feedback of the tap.
    @objc
    func handleTap(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        var tapPoint = DataPoint(cgPoint: tapLocation)
        measureAndIdentify(dataPoint: tapPoint)
        synthesizer.speak(AVSpeechUtterance(string: "Tapped here!"))
    }
    
    /// Places virtual-text of the classification at the touch-location's real-world intersection with a mesh.
    /// Note - because classification of the tapped-mesh is retrieved asynchronously, we visualize the intersection
    /// point immediately to give instant visual feedback of the tap.Escaping closure captures 'inout' parameter
    func measureAndIdentify(dataPoint: DataPoint) -> (distance: Float, classification: String) {
        let point = dataPoint.cgPoint
        var distanceVal: Float = 0
        var classificationStr: String = ""
        // 1. Perform a ray cast against the mesh.
        // Note: Ray-cast option ".estimatedPlane" with alignment ".any" also takes the mesh into account.
        if let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first {
            // ...
            // 2. Visualize the intersection point of the ray with the real-world surface.
            let resultAnchor = AnchorEntity(world: result.worldTransform)
            resultAnchor.addChild(sphere(radius: 0.01, color: .lightGray))
            arView.scene.addAnchor(resultAnchor, removeAfter: scanRefreshInterval)
            // 3. Try to get a classification near the tap location.
            //    Classifications are available per face (in the geometric sense, not human faces).
            nearbyFaceWithClassification(to: result.worldTransform.position) { (centerOfFace, classification) in
                // ...
                DispatchQueue.main.async {
                    // 4. Compute a position for the text which is near the result location, but offset 10 cm
                    // towards the camera (along the ray) to minimize unintentional occlusions of the text by the mesh.
                    let rayDirection = normalize(result.worldTransform.position - self.arView.cameraTransform.translation)
                    let textPositionInWorldCoordinates = result.worldTransform.position - (rayDirection * 0.1)
                    
                    // 5. Create a 3D text to visualize the classification result.
                    let distanceToPoint = round(distance(result.worldTransform.position, self.arView.cameraTransform.translation)*3.28084*100) / 100.0
                    let textEntity = self.model(for: classification, distance: distanceToPoint)
                    classificationStr = classification.description
                    distanceVal = distanceToPoint

                    // 6. Scale the text depending on the distance, such that it always appears with
                    //    the same size on screen.
                    let raycastDistance = distance(result.worldTransform.position, self.arView.cameraTransform.translation)
                    textEntity.scale = .one * raycastDistance

                    // 7. Place the text, facing the camera.
                    var resultWithCameraOrientation = self.arView.cameraTransform
                    resultWithCameraOrientation.translation = textPositionInWorldCoordinates
                    let textAnchor = AnchorEntity(world: resultWithCameraOrientation.matrix)
                    textAnchor.addChild(textEntity)
                    self.arView.scene.addAnchor(textAnchor, removeAfter: self.scanRefreshInterval)
                    
                    dataPoint.classification = classificationStr
                    dataPoint.distance = distanceVal
                    self.pointQueue.enqueue(dataPoint)
//                    if (point.x == 350 && point.y == 350) {
//                        self.synthesizer.speak(AVSpeechUtterance(string: classification.description))
//                    }
                    

                    // 8. Visualize the center of the face (if any was found) for three seconds.
                    //    It is possible that this is nil, e.g. if there was no face close enough to the tap location.
//                    if let centerOfFace = centerOfFace {
//                        let faceAnchor = AnchorEntity(world: centerOfFace)
//                        faceAnchor.addChild(self.sphere(radius: 0.01, color: classification.color))
//                        self.arView.scene.addAnchor(faceAnchor, removeAfter: 1)
//                    }
                }
            }
        }
        return (distance: distanceVal, classification: classificationStr)
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
    }
    
//    @IBAction func toggleMeshButtonPressed(_ button: UIButton) {
//        let isShowingMesh = arView.debugOptions.contains(.showSceneUnderstanding)
//        if isShowingMesh {
//            arView.debugOptions.remove(.showSceneUnderstanding)
//            button.setTitle("Show Mesh", for: [])
//        } else {
//            arView.debugOptions.insert(.showSceneUnderstanding)
//            button.setTitle("Hide Mesh", for: [])
//        }
//    }
    
//    /// - Tag: TogglePlaneDetection
//    @IBAction func togglePlaneDetectionButtonPressed(_ button: UIButton) {
//        guard let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else {
//            return
//        }
//        if configuration.planeDetection == [] {
//            configuration.planeDetection = [.horizontal, .vertical]
//            button.setTitle("Stop Plane Detection", for: [])
//        } else {
//            configuration.planeDetection = []
//            button.setTitle("Start Plane Detection", for: [])
//        }
//        arView.session.run(configuration)
//    }
    
    func nearbyFaceWithClassification(to location: SIMD3<Float>, completionBlock: @escaping (SIMD3<Float>?, ARMeshClassification) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completionBlock(nil, .none)
            return
        }
    
        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        
        // Sort the mesh anchors by distance to the given location and filter out
        // any anchors that are too far away (4 meters is a safe upper limit).
        let cutoffDistance: Float = 4.0
        meshAnchors.removeAll { distance($0.transform.position, location) > cutoffDistance }
        meshAnchors.sort { distance($0.transform.position, location) < distance($1.transform.position, location) }

        // Perform the search asynchronously in order not to stall rendering.
        DispatchQueue.global().async {
            for anchor in meshAnchors {
                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    
                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).position
                     
                    // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                    let distanceToFace = distance(centerWorldPosition, location)
                    if distanceToFace <= 0.05 {
                        // Get the semantic classification of the face and finish the search.
                        let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                        completionBlock(centerWorldPosition, classification)
                        return
                    }
                }
            }
            
            // Let the completion block know that no result was found.
            completionBlock(nil, .none)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
        
    func model(for classification: ARMeshClassification, distance: Float) -> ModelEntity {
//        // Return cached model if available
//        if let model = modelsForClassification[classification] {
//            model.transform = .identity
//            return model.clone(recursive: true)
//        }
        
        // Generate 3D text for the classification
        let lineHeight: CGFloat = 0.05
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMesh = MeshResource.generateText(classification.description + "\n" + String(distance) + "ft", extrusionDepth: Float(lineHeight * 0.1), font: font)
//        let textMesh = MeshResource.generateText(String(distance), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMaterial = SimpleMaterial(color: classification.color, isMetallic: true)
        let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Move text geometry to the left so that its local origin is in the center
        model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
        // Add model to cache
        modelsForClassification[classification] = model
        return model
    }
    
    func sphere(radius: Float, color: UIColor) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
        // Move sphere up by half its diameter so that it does not intersect with the mesh
        sphere.position.y = radius
        return sphere
    }
    
    
}

class DataPoint{
    var cgPoint: CGPoint
    var distance: Float
    var classification: String
    
    init(cgPoint: CGPoint) {
        self.cgPoint = cgPoint
        self.distance = 0
        self.classification = ""
    }
    
    init(distance: Float) {
        self.cgPoint = CGPointMake(0, 0)
        self.distance = distance
        self.classification = ""
    }
    
}

struct Queue<T> {
  private var elements: [T] = []

  mutating func enqueue(_ value: T) {
    elements.append(value)
  }

  mutating func dequeue() -> T? {
    guard !elements.isEmpty else {
      return nil
    }
    return elements.removeFirst()
  }
    mutating func dequeueAll() -> [T] {
        let elementsCopy = elements
        elements = []
        return elementsCopy
    }

  var head: T? {
    return elements.first
  }

  var tail: T? {
    return elements.last
  }

    var isEmpty: Bool {
        return elements.isEmpty
    }
    
    var size: Int {
        return elements.count
    }
}
