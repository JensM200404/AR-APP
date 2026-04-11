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
    private var graveWorldPosition: SCNVector3?
    private var originCoordinate: CLLocationCoordinate2D?

    private let configuration: ARWorldTrackingConfiguration = {
        let c = ARWorldTrackingConfiguration()
        c.worldAlignment = .gravityAndHeading
        c.planeDetection = .horizontal
        return c
    }()

    override init() {
        super.init()
        sceneView.delegate        = self
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
        print("[AR] Origin: \(coordinate.latitude), \(coordinate.longitude)")
        if let grave = targetGrave {
            computeGraveWorldPosition(for: grave)
            buildGraveMarker()
            buildArrow()
        }
    }

    func startNavigation(to grave: GraveRecord) {
        stopNavigation()
        targetGrave = grave
        guard originCoordinate != nil else { return }
        computeGraveWorldPosition(for: grave)
        buildGraveMarker()
        buildArrow()
    }

    func stopNavigation() {
        arrowNode?.removeFromParentNode();       arrowNode = nil
        graveMarkerNode?.removeFromParentNode(); graveMarkerNode = nil
        graveWorldPosition = nil
        targetGrave = nil
    }

    private func computeGraveWorldPosition(for grave: GraveRecord) {
        guard let origin = originCoordinate else { return }
        let off = worldOffset(from: origin, to: grave.coordinate)
        graveWorldPosition = SCNVector3(off.x, 0, off.z)
    }

    private func buildGraveMarker() {
        guard let pos = graveWorldPosition, let grave = targetGrave else { return }

        let root = SCNNode()
        root.position = SCNVector3(pos.x, 0, pos.z)

        let cube = SCNBox(width: 0.4, height: 0.4, length: 0.4, chamferRadius: 0.04)
        cube.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        cube.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.7)
        cube.firstMaterial?.transparency = 0.85
        let cubeNode = SCNNode(geometry: cube)
        cubeNode.position = SCNVector3(0, 0.2, 0)

        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.fromValue    = 0
        spin.toValue      = Float.pi * 2
        spin.duration     = 4.0
        spin.repeatCount  = .infinity
        cubeNode.addAnimation(spin, forKey: "spin")

        let beam = SCNCylinder(radius: 0.04, height: 6.0)
        beam.firstMaterial?.diffuse.contents  = UIColor.systemYellow.withAlphaComponent(0.35)
        beam.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.25)
        beam.firstMaterial?.isDoubleSided     = true
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, 3.0, 0)

        let ring = SCNTorus(ringRadius: 0.6, pipeRadius: 0.03)
        ring.firstMaterial?.diffuse.contents  = UIColor.systemYellow.withAlphaComponent(0.5)
        ring.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.3)
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.01, 0)

        let ringPulse = CABasicAnimation(keyPath: "geometry.pipeRadius")
        ringPulse.fromValue   = 0.03
        ringPulse.toValue     = 0.055
        ringPulse.duration    = 1.2
        ringPulse.autoreverses = true
        ringPulse.repeatCount  = .infinity
        ringNode.addAnimation(ringPulse, forKey: "ringPulse")

        let sonar = SCNTorus(ringRadius: 1.0, pipeRadius: 0.015)
        sonar.firstMaterial?.diffuse.contents  = UIColor.white.withAlphaComponent(0.2)
        sonar.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.15)
        let sonarNode = SCNNode(geometry: sonar)
        sonarNode.position = SCNVector3(0, 0.01, 0)

        let sonarFade = CABasicAnimation(keyPath: "opacity")
        sonarFade.fromValue   = 0.7
        sonarFade.toValue     = 0.0
        sonarFade.duration    = 1.8
        sonarFade.repeatCount  = .infinity
        sonarNode.addAnimation(sonarFade, forKey: "sonarFade")

        let bg = SCNPlane(width: 1.4, height: 0.55)
        bg.cornerRadius = 0.07
        bg.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.7)
        bg.firstMaterial?.isDoubleSided    = true
        let bgNode = SCNNode(geometry: bg)
        bgNode.position = SCNVector3(0, 6.5, 0)

        let nameText = SCNText(string: grave.fullName, extrusionDepth: 0.002)
        nameText.font = UIFont.systemFont(ofSize: 0.14, weight: .bold)
        nameText.firstMaterial?.diffuse.contents  = UIColor.white
        nameText.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.9)
        nameText.alignmentMode  = CATextLayerAlignmentMode.center.rawValue
        nameText.containerFrame = CGRect(x: -0.6, y: 0.1, width: 1.2, height: 0.22)
        nameText.isWrapped      = true
        let nameNode = SCNNode(geometry: nameText)
        nameNode.position = SCNVector3(-0.6, 6.35, 0.01)

        let subText = SCNText(string: grave.lifespan, extrusionDepth: 0.001)
        subText.font = UIFont.systemFont(ofSize: 0.1, weight: .regular)
        subText.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        subText.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.8)
        subText.alignmentMode  = CATextLayerAlignmentMode.center.rawValue
        subText.containerFrame = CGRect(x: -0.6, y: 0, width: 1.2, height: 0.18)
        subText.isWrapped      = true
        let subNode = SCNNode(geometry: subText)
        subNode.position = SCNVector3(-0.6, 6.17, 0.01)

        let bb = SCNBillboardConstraint()
        bb.freeAxes = .Y
        bgNode.constraints   = [bb]
        nameNode.constraints = [bb]
        subNode.constraints  = [bb]

        root.addChildNode(cubeNode)
        root.addChildNode(beamNode)
        root.addChildNode(ringNode)
        root.addChildNode(sonarNode)
        root.addChildNode(bgNode)
        root.addChildNode(nameNode)
        root.addChildNode(subNode)

        sceneView.scene.rootNode.addChildNode(root)
        graveMarkerNode = root
    }

    private func buildArrow() {
        arrowNode?.removeFromParentNode()

        let root = SCNNode()

        let shaft = SCNBox(width: 0.08, height: 0.08, length: 0.45, chamferRadius: 0.01)
        shaft.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        shaft.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.8)
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position = SCNVector3(0, 0, -0.1)

        let head = SCNPyramid(width: 0.22, height: 0.30, length: 0.22)
        head.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        head.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.9)
        let headNode = SCNNode(geometry: head)
        headNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        headNode.position    = SCNVector3(0, 0, 0.28)

        let tail = SCNSphere(radius: 0.06)
        tail.firstMaterial?.diffuse.contents  = UIColor.white.withAlphaComponent(0.6)
        tail.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.4)
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(0, 0, -0.325)

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue   = 1.0
        pulse.toValue     = 0.4
        pulse.duration    = 0.8
        pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        root.addAnimation(pulse, forKey: "pulse")

        root.addChildNode(shaftNode)
        root.addChildNode(headNode)
        root.addChildNode(tailNode)

        root.position = SCNVector3(0, 1.2, 0)

        sceneView.scene.rootNode.addChildNode(root)
        arrowNode = root
    }

    private func updateArrow(frame: ARFrame) {
        guard let arrow = arrowNode,
              let gravePos = graveWorldPosition else { return }

        let cam    = frame.camera.transform
        let camX   = cam.columns.3.x
        let camY   = cam.columns.3.y
        let camZ   = cam.columns.3.z

        let dx     = gravePos.x - camX
        let dz     = gravePos.z - camZ
        let dist   = sqrt(dx * dx + dz * dz)

        if dist < 0.5 {
            arrow.isHidden = true
            return
        }
        arrow.isHidden = false

        let nx = dx / dist
        let nz = dz / dist

        let offsetDist: Float = min(1.5, dist * 0.4)
        arrow.position = SCNVector3(
            camX + nx * offsetDist,
            camY - 0.3,
            camZ + nz * offsetDist
        )

        let angle = atan2(dx, dz)
        arrow.eulerAngles = SCNVector3(0, angle, 0)
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
        updateArrow(frame: frame)
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
