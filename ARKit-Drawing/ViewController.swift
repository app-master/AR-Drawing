import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            removePlaneNode()  
            reloadConfiguration()
        }
    }
    
    var selectedNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configuration.planeDetection = .horizontal
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.debugOptions = .showWorldOrigin
        
        addGestureRecognizer()
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
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        
        selectedNode = node
        
        dismiss(animated: true, completion: nil)
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
    }
    
    func undoLastObject() {
        
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: Methods

extension ViewController {
    
    func addGestureRecognizer() {
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
        self.sceneView.addGestureRecognizer(tapGesture)
        
    }
    
    @objc func handleTap(gesture: UITapGestureRecognizer) {
        
        guard let node = selectedNode else { return }
        
        let location = gesture.location(in: sceneView)
        
        switch objectMode {
            
            case .freeform:
                
                inFrontAddNode(node: node)
            
            case .plane:
            
               addNode(node, to: location)
            
            case .image:
                
                break
        }
        
    }
    
    func reloadConfiguration() {
        configuration.detectionImages = objectMode == .image ? ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) : nil
        sceneView.session.run(configuration)
    }
    
    func addNode(_ node: SCNNode, to location: CGPoint) {
        
        let results = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        
        guard let result = results.first else { return }
        
        node.simdTransform = result.worldTransform
        
        let parentNode = sceneView.scene.rootNode
        
        addNode(node, to: parentNode)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        
        guard let selectedNode = selectedNode else { return }
        
        addNode(selectedNode, to: node)
        
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        let planeNode = createPlaneNode(for: anchor)
        
        addNode(planeNode, to: node)
        
    }
    
    func createPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        
        let geometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        
        let planeNode = SCNNode(geometry: geometry)
        planeNode.name = "Plane"
        planeNode.opacity = 0.3
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        
        return planeNode
    }
    
    func removePlaneNode() {
        
        sceneView.scene.rootNode.enumerateChildNodes{ node, _ in
            
            if node.name == "Plane" {
                node.removeFromParentNode()
            }
            
        }
        
    }
    
    func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        node.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        
        guard let plane = node.geometry as? SCNPlane else  { return }
        
        plane.width = CGFloat(anchor.extent.x)
        plane.height = CGFloat(anchor.extent.z)
        
    }
    
    func inFrontAddNode(node: SCNNode) {
        
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else { return }
        
        var transform = matrix_identity_float4x4
        
        transform.columns.3.z = -0.2
        
        node.simdTransform = matrix_multiply(cameraTransform, transform)
        
        let parentNode = sceneView.scene.rootNode
        
        addNode(node, to: parentNode)
        
    }
    
    
    func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        let cloneNode = node.clone()
        parentNode.addChildNode(cloneNode)
    }

}

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let imageAnchor = anchor as? ARImageAnchor {
            
            nodeAdded(node, for: imageAnchor)
            
        } else if let planeAnchor = anchor as? ARPlaneAnchor {
            
            if objectMode == .plane {
                nodeAdded(node, for: planeAnchor)
            }
            
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        guard let planeNode = node.childNodes.first else { return }
        
        if objectMode == .plane {
            updatePlaneNode(planeNode, for: planeAnchor)
        }
        
    }
    
}
