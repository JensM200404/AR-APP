// ARSessionManager.swift
// AR Cemetery Navigator – ARKit Session, AR Arrow & Grave Marker
//
// v8 changes:
//   • Redesigned the navigation arrow geometry. The old composite (flat
//     SCNBox shaft + rotated SCNPyramid head) read poorly as an arrow in
//     testing. It is now a single extruded SCNShape built from a 2D arrow
//     silhouette (pointed head + shaft + notched chevron tail), kept 3D via
//     extrusionDepth. The "pulse" animation and the per-frame updateArrow()
//     rotation logic are unchanged — the arrow still points along local +Z.
//
// v7 changes:
//   • Added setSceneOpacity(_:) — dims all AR nodes when tracking is
//     unreliable, giving the user a clear visual signal that AR content
//     should not be fully trusted. Opacity is restored when tracking
//     returns to normal.

import ARKit
import SceneKit
import CoreLocation
import UIKit

// MARK: - Delegate

protocol ARSessionManagerDelegate: AnyObject {
    func arSessionManager(_ manager: ARSessionManager,
                          didUpdateFrame frame: ARFrame)
    func arSessionManager(_ manager: ARSessionManager,
                          didChangeTrackingState state: ARCamera.TrackingState)
}

// MARK: - ARSessionManager

final class ARSessionManager: NSObject {

    // MARK: Public

    weak var delegate: ARSessionManagerDelegate?

    let sceneView: ARSCNView = {
        let v = ARSCNView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.automaticallyUpdatesLighting = true
        v.debugOptions = []
        return v
    }()

    // MARK: Private – nodes

    private var arrowNode: SCNNode?
    private var graveMarkerNode: SCNNode?

    // MARK: Private – state

    private var targetGrave: GraveRecord?
    private var graveWorldPosition: SIMD3<Float>?
    private var originCoordinate: CLLocationCoordinate2D?

    // MARK: Private – session

    private let configuration: ARWorldTrackingConfiguration = {
        let c = ARWorldTrackingConfiguration()
        c.worldAlignment = .gravityAndHeading
        c.planeDetection = .horizontal
        return c
    }()

    // MARK: Init

    override init() {
        super.init()
        sceneView.delegate         = self
        sceneView.session.delegate = self
    }

    // MARK: - Session

    func startSession() {
        sceneView.session.run(configuration,
                              options: [.resetTracking, .removeExistingAnchors])
    }

    func pauseSession() {
        sceneView.session.pause()
    }

    // MARK: - GPS origin

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

    // MARK: - Navigation

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

    // MARK: - Opacity control
    //
    // Called by ViewController when tracking state changes.
    // Dimming the AR nodes gives the user a clear visual signal
    // that the content is unreliable without removing it entirely —
    // the user can still see the approximate direction.

    func setSceneOpacity(_ opacity: CGFloat) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        arrowNode?.opacity       = opacity
        graveMarkerNode?.opacity = opacity
        SCNTransaction.commit()
    }

    // MARK: - Build: 3D Arrow
    //
    // v8: The arrow is now a single extruded SCNShape built from a 2D arrow
    // silhouette (pointed head + shaft + notched chevron tail). Testers found
    // the old box-shaft + pyramid-head composite hard to read as an arrow; a
    // solid, Google-Maps-style profile is unmistakable while still being 3D.
    //
    // Orientation contract (unchanged from before): the arrow must point along
    // its local +Z so that updateArrow(...) — which sets the *root* node's
    // Y-euler to aim at the grave — keeps working as-is. The fixed "lay-flat
    // and tilt up" orientation therefore lives on a CHILD node, because the
    // root's eulerAngles are overwritten every frame.

    private func buildArrow() {
        let root = SCNNode()
        root.name = "arrowRoot"

        // --- Geometry: extruded 2D arrow profile ---
        let depth: CGFloat = 0.08
        let shape = SCNShape(path: arrowProfilePath(), extrusionDepth: depth)
        shape.chamferRadius = 0.012
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor.systemYellow
        mat.emission.contents = UIColor.systemYellow.withAlphaComponent(0.6)
        mat.lightingModel     = .phong
        mat.isDoubleSided     = true          // visible from both faces when tilted
        shape.firstMaterial   = mat

        // The profile is drawn in the XY plane pointing +Y and extruded along
        // +Z. Lay it flat so the arrow points along +Z, parallel to the ground.
        let layFlat: Float = .pi / 2          // +Y(profile) -> +Z(world): points forward
        let liftUp: Float  = 0                // flat: no upward tilt of the tip
        let shapeNode = SCNNode(geometry: shape)
        shapeNode.eulerAngles = SCNVector3(layFlat - liftUp, 0, 0)
        shapeNode.scale       = SCNVector3(1.3, 1.3, 1.3)   // bold, easy to spot
        // Centre the extrusion thickness on the node origin.
        shapeNode.pivot       = SCNMatrix4MakeTranslation(0, 0, Float(depth / 2))
        shapeNode.position    = SCNVector3(0, 0.02, 0)

        // Schaduwschijf
        let shadow = SCNCylinder(radius: 0.24, height: 0.005)
        shadow.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.25)
        shadow.firstMaterial?.lightingModel    = .constant
        let shadowNode = SCNNode(geometry: shadow)
        shadowNode.position = SCNVector3(0, -0.06, 0.05)

        // Pulserende animatie
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue    = 1.0
        pulse.toValue      = 0.5
        pulse.duration     = 0.85
        pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        root.addAnimation(pulse, forKey: "pulse")

        root.addChildNode(shadowNode)
        root.addChildNode(shapeNode)

        sceneView.scene.rootNode.addChildNode(root)
        arrowNode = root
    }

    /// Closed 2D outline of a navigation arrow, drawn in the XY plane pointing
    /// along +Y and centred on the origin. Head + straight shaft + a concave
    /// chevron notch at the tail give it an immediately recognisable arrow read.
    private func arrowProfilePath() -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to:    CGPoint(x:  0.00, y:  0.34))   // tip
        p.addLine(to: CGPoint(x: -0.22, y:  0.06))   // left head wing
        p.addLine(to: CGPoint(x: -0.09, y:  0.06))   // left shaft (top)
        p.addLine(to: CGPoint(x: -0.09, y: -0.30))   // left shaft (bottom)
        p.addLine(to: CGPoint(x:  0.00, y: -0.20))   // tail notch (concave)
        p.addLine(to: CGPoint(x:  0.09, y: -0.30))   // right shaft (bottom)
        p.addLine(to: CGPoint(x:  0.09, y:  0.06))   // right shaft (top)
        p.addLine(to: CGPoint(x:  0.22, y:  0.06))   // right head wing
        p.close()                                    // back to tip
        return p
    }

    // MARK: - Build: Grave Marker

    private func buildGraveMarker() {
        graveMarkerNode?.removeFromParentNode()
        guard let pos = graveWorldPosition, let grave = targetGrave else { return }

        let root = SCNNode()
        root.position = SCNVector3(pos.x, 0, pos.z)

        // Roterende kubus
        let cube = SCNBox(width: 0.4, height: 0.4, length: 0.4, chamferRadius: 0.04)
        cube.firstMaterial?.diffuse.contents  = UIColor.systemYellow
        cube.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.6)
        cube.firstMaterial?.transparency      = 0.85
        let cubeNode = SCNNode(geometry: cube)
        cubeNode.position = SCNVector3(0, 0.2, 0)

        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.toValue     = Float.pi * 2
        spin.duration    = 4.0
        spin.repeatCount = .infinity
        cubeNode.addAnimation(spin, forKey: "spin")

        // Verticale lichtbalk
        let beam = SCNCylinder(radius: 0.03, height: 6.0)
        beam.firstMaterial?.diffuse.contents  = UIColor.systemYellow.withAlphaComponent(0.3)
        beam.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.2)
        beam.firstMaterial?.isDoubleSided     = true
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, 3.0, 0)

        // Pulserende grondring
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

        // Billboard naambord
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

    // MARK: - Per-frame arrow update

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

        arrow.position = SCNVector3(cx + nx * 1.8, cy - 0.25, cz + nz * 1.8)

        if let gravePos = graveWorldPosition {
            let dx = gravePos.x - arrow.position.x
            let dz = gravePos.z - arrow.position.z
            arrow.eulerAngles = SCNVector3(0, atan2(dx, dz), 0)
        }
    }

    // MARK: - Coordinate math

    func worldOffset(from origin: CLLocationCoordinate2D,
                     to target: CLLocationCoordinate2D) -> (x: Float, z: Float) {
        let mPerLat = 111_320.0
        let mPerLon = 111_320.0 * cos(origin.latitude * .pi / 180)
        let x = Float((target.longitude - origin.longitude) * mPerLon)
        let z = Float(-(target.latitude  - origin.latitude) * mPerLat)
        return (x, z)
    }
}

// MARK: - ARSCNViewDelegate

extension ARSessionManager: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = sceneView.session.currentFrame else { return }
        updateArrow(cameraTransform: frame.camera.transform)
    }
}

// MARK: - ARSessionDelegate

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
