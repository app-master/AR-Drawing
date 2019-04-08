import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var addedObjectsLabel: UILabel!
    @IBOutlet weak var addedPlanesLabel: UILabel!
    
    var optionsViewController: OptionsContainerViewController?
    
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            reloadConfiguration()
        }
    }
    
    var selectedNode: SCNNode?
    
    var objectsArray = [SCNNode]()
    
    var planesArray = [SCNNode]()
    
    var planeVisualization = false {
        didSet {
            planesArray.forEach { node in
                node.isHidden = !planeVisualization
            }
        }
    }
    
    private var distance: Float {
        get {
            if optionsViewController?.selectedOption == .addShape {
                return selectedNode!.boundingSphere.radius
            }
            return 0.1
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.debugOptions = .showWorldOrigin
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            planeVisualization = false
        case 1:
            objectMode = .plane
            planeVisualization = true
        case 2:
            objectMode = .image
            planeVisualization = false
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsVC = segue.destination as! OptionsContainerViewController
            optionsVC.delegate = self
            optionsViewController = optionsVC
        }
    }
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        
        selectedNode = node
        
        dismiss(animated: true, completion: nil)
    }
    
    func togglePlaneVisualization() {
        planeVisualization = !planeVisualization
        dismiss(animated: true, completion: nil)
    }
    
    func undoLastObject() {
        
        let lastObject = objectsArray.last
        lastObject?.removeFromParentNode()
        objectsArray.removeLast()
        
        DispatchQueue.main.async {
            self.addedObjectsLabel.text = "Added objects: \(self.objectsArray.count)"
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func resetScene() {
        
        objectsArray.forEach { node in
            node.removeFromParentNode()
        }
        
        objectsArray.removeAll()
        
        planesArray.forEach { node in
            node.removeFromParentNode()
        }
        
        planesArray.removeAll()
        
        DispatchQueue.main.async {
            self.addedPlanesLabel.text = "Added planes: \(self.planesArray.count)"
        }
        
        DispatchQueue.main.async {
            self.addedObjectsLabel.text = "Added objects: \(self.objectsArray.count)"
        }
        
        reloadConfiguration(removeAnchors: true)
        
        dismiss(animated: true, completion: nil)
    }
}

// MARK: Methods

extension ViewController {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let node = selectedNode else { return }
        
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: sceneView)
        
        switch objectMode {
            case .freeform:
                inFrontAddNode(node)
            case .plane:
                addNode(node, toTouchPoint: location)
            case .image:
                break
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    
        guard let node = selectedNode else { return }
        
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: sceneView)
        
        addNode(node, toTouchPoint: location)
        
    }
    
    func reloadConfiguration(removeAnchors: Bool = false) {
        configuration.detectionImages = objectMode == .image ? ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) : nil
        configuration.planeDetection = [.horizontal, .vertical]
        
        if removeAnchors {
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        } else {
           sceneView.session.run(configuration)
        }
    }
    
    func addNode(_ node: SCNNode, toTouchPoint point: CGPoint) {
        
        func getTranslateForARResult(result: ARHitTestResult) -> SCNVector3 {
            let transform = result.worldTransform
            let translate = transform.columns.3
            let x = translate.x
            let y = translate.y
            let z = translate.z
            
            return SCNVector3(x, y, z)
        }
        
        switch objectMode {
        case .freeform:
            let results = sceneView.hitTest(point, types: .featurePoint)
            guard let result = results.first else { return }
            node.position = getTranslateForARResult(result: result)
        case .plane:
            let results = sceneView.hitTest(point, types: .existingPlaneUsingExtent)
            guard let result = results.first else { return }
            node.position = getTranslateForARResult(result: result)
        case .image: 
            let results = sceneView.hitTest(point, options: [.searchMode : 1])
            guard let result = results.first else { return }
            guard let _ = sceneView.anchor(for: result.node) as? ARImageAnchor  else {
                return
            }
            node.position = result.worldCoordinates
        }
        
        let last = objectsArray.last
        
        if last != nil {
            
            let lastCenter = last!.convertPosition(last!.boundingSphere.center, to: sceneView.scene.rootNode)
            let nextCenter = node.convertPosition(node.boundingSphere.center, to: sceneView.scene.rootNode)
            
            if (abs(abs(lastCenter.x) - abs(nextCenter.x)) < distance) &&
                (abs(abs(lastCenter.y) - abs(nextCenter.y)) < distance) &&
                (abs(abs(lastCenter.z) - abs(nextCenter.z)) < distance) {
                return
            }
            
        }
        
        let parentNode = sceneView.scene.rootNode
        
        addNode(node, toParentNode: parentNode)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        
        guard let selectedNode = selectedNode else { return }
        
        let node1 = SCNNode(geometry: SCNPlane(width: anchor.referenceImage.physicalSize.width, height: anchor.referenceImage.physicalSize.height))
        node1.eulerAngles.x = -.pi / 2
        node1.opacity = 0.01
        
        addNode(node1, toParentNode: node)
        
        addNode(selectedNode, toParentNode: node)
        
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        let planeNode = createPlaneNode(for: anchor)
        
        planeNode.isHidden = !planeVisualization
        
        addNode(planeNode, toParentNode: node)
        
    }
    
    func createPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        
        let geometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        
        let planeNode = SCNNode(geometry: geometry)
        planeNode.opacity = 0.3
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        
        return planeNode
    }
    
    func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        node.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        
        guard let plane = node.geometry as? SCNPlane else  { return }
        
        plane.width = CGFloat(anchor.extent.x)
        plane.height = CGFloat(anchor.extent.z)
        
    }
    
    func inFrontAddNode(_ node: SCNNode) {
        
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else { return }
        
        var transform = matrix_identity_float4x4
        
        transform.columns.3.z = -0.2
        
        node.simdTransform = matrix_multiply(cameraTransform, transform)
        
        let parentNode = sceneView.scene.rootNode
        
        addNode(node, toParentNode: parentNode)
        
    }
    
    
    func addNode(_ node: SCNNode, toParentNode parentNode: SCNNode) {
        if node.geometry is SCNPlane {
            parentNode.addChildNode(node)
            planesArray.append(node)
            DispatchQueue.main.async {
               self.addedPlanesLabel.text = "Added planes: \(self.planesArray.count)"
            }
        } else {
            let cloneNode = node.clone()
            parentNode.addChildNode(cloneNode)
            objectsArray.append(cloneNode)
            DispatchQueue.main.async {
               self.addedObjectsLabel.text = "Added objects: \(self.objectsArray.count)"
            }
        }
    }

}

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let imageAnchor = anchor as? ARImageAnchor {
            
            nodeAdded(node, for: imageAnchor)
            
        } else if let planeAnchor = anchor as? ARPlaneAnchor {
            
            nodeAdded(node, for: planeAnchor)
            
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        guard let planeNode = node.childNodes.first else { return }
        
        updatePlaneNode(planeNode, for: planeAnchor)
        
    }
    
}
