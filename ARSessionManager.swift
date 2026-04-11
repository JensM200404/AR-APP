import ARKit
import SceneKit
import CoreLocation
import UIKit

protocol ARSessionManagerDelegate: AnyObject {
    func arSessionManager(_ manager: ARSessionManager,
                          didUpdateFrame frame: ARFrame)
    func arSessionManager(_ manager: ARSessionManager,
                          didChangeTrackingState state: ARCamera.TrackingState)
}

final class ARSessionManager: NSObject {

    weak var delegate: ARSessionManagerDelegate?

    let sceneView: ARSCNView = {
        let v = ARSCNView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.automaticallyUpdatesLighting = true
        v.debugOptions = []
        return v
    }()

    private var arrowNode: SCNNode?
    private var graveMarkerNode: SCNNode?

    private var targetGrave: GraveRecord?
    private var graveWorldPosition: SIMD3<Float>?
    private var originCoordinate: CLLocationCoordinate2D?

    private let configuration: ARWorldTrackingConfiguration = {
        let c = ARWorldTrackingConfiguration()
        c.worldAlignment = .gravityAndHeading
        c.planeDetection = .horizontal
        return c
    }()

    override init() {
        super.init()
        sceneView.delegate         = self
        sceneView.session.delegate = self
    }

    func startSession() {
        sceneView.session.run(configuration,
                              options: [.resetTracking, .removeExistingAnchors])
    }

    func pauseSession() {
        sceneView.session.pause()
    }

    func setOrigin(coordinate: CLLocationCoordinate2D) {
        guard originCoordinate == nil else { return }
        originCoordinate = coordinate
        print("[AR] Origin set: \(coordinate.latitude), \(coordinate.longitude)")
        if let grave = targetGrave {
            let off = worldOffset(from: coordinate, to: grave.coordinate)
            graveWorldPosition = SIMD3<Float>(off.x, 0, off.z)
            buildGraveMarker()
        }
    }

    func startNavigation(to grave: GraveRecord) {
        stopNavigation()
        targetGrave = grave
        if let origin = originCoordinate {
            let off = worldOffset(from: origin, to: grave.coordinate)
            graveWorldPosition = SIMD3<Float>(off.x, 0, off.z)
            buildGraveMarker()
        }
        buildArrow()
    }

    func stopNavigation() {
        arrowNode?.removeFromParentNode();       arrowNode = nil
        graveMarkerNode?.removeFromParentNode(); graveMarkerNode = nil
        graveWorldPosition = nil
        targetGrave = nil
    }

    private func buildArrow() {
        let root = SCNNode()
        root.name = "arrowRoot"

        let body = SCNBox(width: 0.18,
                          height: 0.06,
                          length: 0.42,
                          chamferRadius: 0.015)
        body.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        body.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.55)
        body.firstMaterial?.lightingModel     = .phong
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0, 0)

        let head = SCNPyramid(width: 0.38,
                              height: 0.28,
                              length: 0.38)
        head.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        head.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.65)
        head.firstMaterial?.lightingModel     = .phong
        let headNode = SCNNode(geometry: head)
        headNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        headNode.position = SCNVector3(0, 0, 0.21 + 0.14)

        let shadow = SCNCylinder(radius: 0.22, height: 0.005)
        shadow.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.25)
        shadow.firstMaterial?.lightingModel    = .constant
        let shadowNode = SCNNode(geometry: shadow)
        shadowNode.position = SCNVector3(0, -0.04, 0.1)

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue    = 1.0
        pulse.toValue      = 0.5
        pulse.duration     = 0.85
        pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        root.addAnimation(pulse, forKey: "pulse")

        root.addChildNode(shadowNode)
        root.addChildNode(bodyNode)
        root.addChildNode(headNode)

        sceneView.scene.rootNode.addChildNode(root)
        arrowNode = root
    }

    private func buildGraveMarker() {
        graveMarkerNode?.removeFromParentNode()
        guard let pos = graveWorldPosition, let grave = targetGrave else { return }

        let root = SCNNode()
        root.position = SCNVector3(pos.x, 0, pos.z)

        let cube = SCNBox(width: 0.4, height: 0.4, length: 0.4, chamferRadius: 0.04)
        cube.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        cube.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.6)
        cube.firstMaterial?.transparency      = 0.85
        let cubeNode = SCNNode(geometry: cube)
        cubeNode.position = SCNVector3(0, 0.2, 0)

        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.fromValue   = 0
        spin.toValue     = Float.pi * 2
        spin.duration    = 4.0
        spin.repeatCount = .infinity
        cubeNode.addAnimation(spin, forKey: "spin")

        let beam = SCNCylinder(radius: 0.03, height: 6.0)
        beam.firstMaterial?.diffuse.contents  = UIColor.systemYellow.withAlphaComponent(0.3)
        beam.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.2)
        beam.firstMaterial?.isDoubleSided     = true
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, 3.0, 0)

        let ring = SCNTorus(ringRadius: 0.6, pipeRadius: 0.03)
        ring.firstMaterial?.diffuse.contents  = UIColor.systemYellow.withAlphaComponent(0.5)
        ring.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.3)
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.01, 0)

        let ringPulse = CABasicAnimation(keyPath: "geometry.pipeRadius")
        ringPulse.fromValue    = 0.03
        ringPulse.toValue      = 0.055
        ringPulse.duration     = 1.2
        ringPulse.autoreverses = true
        ringPulse.repeatCount  = .infinity
        ringNode.addAnimation(ringPulse, forKey: "ringPulse")

        let bg = SCNPlane(width: 3.2, height: 1.2)
        bg.cornerRadius = 0.12
        bg.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.72)
        bg.firstMaterial?.isDoubleSided    = true
        let bgNode = SCNNode(geometry: bg)
        bgNode.position = SCNVector3(0, 7.2, 0)

        let nameText = SCNText(string: grave.fullName, extrusionDepth: 0.005)
        nameText.font           = UIFont.systemFont(ofSize: 0.38, weight: .bold)
        nameText.firstMaterial?.diffuse.contents  = UIColor.white
        nameText.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.9)
        nameText.alignmentMode  = CATextLayerAlignmentMode.center.rawValue
        nameText.containerFrame = CGRect(x: -1.4, y: 0.28, width: 2.8, height: 0.55)
        nameText.isWrapped      = true
        let nameNode = SCNNode(geometry: nameText)
        nameNode.position = SCNVector3(-1.4, 6.85, 0.02)

        let subText = SCNText(string: grave.lifespan, extrusionDepth: 0.003)
        subText.font           = UIFont.systemFont(ofSize: 0.28, weight: .regular)
        subText.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        subText.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.85)
        subText.alignmentMode  = CATextLayerAlignmentMode.center.rawValue
        subText.containerFrame = CGRect(x: -1.4, y: 0, width: 2.8, height: 0.42)
        subText.isWrapped      = true
        let subNode = SCNNode(geometry: subText)
        subNode.position = SCNVector3(-1.4, 6.58, 0.02)

        let bb = SCNBillboardConstraint()
        bb.freeAxes = .Y
        bgNode.constraints   = [bb]
        nameNode.constraints = [bb]
        subNode.constraints  = [bb]

        root.addChildNode(cubeNode)
        root.addChildNode(beamNode)
        root.addChildNode(ringNode)
        root.addChildNode(bgNode)
        root.addChildNode(nameNode)
        root.addChildNode(subNode)

        sceneView.scene.rootNode.addChildNode(root)
        graveMarkerNode = root
    }

    private func updateArrow(cameraTransform: simd_float4x4) {
        guard let arrow = arrowNode else { return }

        let cx = cameraTransform.columns.3.x
        let cy = cameraTransform.columns.3.y
        let cz = cameraTransform.columns.3.z

        let fwdX = -cameraTransform.columns.2.x
        let fwdZ = -cameraTransform.columns.2.z
        let fwdLen = sqrt(fwdX * fwdX + fwdZ * fwdZ)
        let nx: Float = fwdLen > 0.001 ? fwdX / fwdLen : 0
        let nz: Float = fwdLen > 0.001 ? fwdZ / fwdLen : -1

        arrow.position = SCNVector3(cx + nx * 1.8,
                                    cy - 0.25,
                                    cz + nz * 1.8)

        if let gravePos = graveWorldPosition {
            let dx = gravePos.x - arrow.position.x
            let dz = gravePos.z - arrow.position.z
            arrow.eulerAngles = SCNVector3(0, atan2(dx, dz), 0)
        }
    }

    func worldOffset(from origin: CLLocationCoordinate2D,
                     to target: CLLocationCoordinate2D) -> (x: Float, z: Float) {
        let mPerLat = 111_320.0
        let mPerLon = 111_320.0 * cos(origin.latitude * .pi / 180)
        let x = Float((target.longitude - origin.longitude) * mPerLon)
        let z = Float(-(target.latitude  - origin.latitude) * mPerLat)
        return (x, z)
    }
}

extension ARSessionManager: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = sceneView.session.currentFrame else { return }
        updateArrow(cameraTransform: frame.camera.transform)
    }
}

extension ARSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        delegate?.arSessionManager(self, didUpdateFrame: frame)
    }

    func session(_ session: ARSession,
                 cameraDidChangeTrackingState camera: ARCamera) {
        delegate?.arSessionManager(self, didChangeTrackingState: camera.trackingState)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[AR] Session failed: \(error.localizedDescription)")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
    }
}
