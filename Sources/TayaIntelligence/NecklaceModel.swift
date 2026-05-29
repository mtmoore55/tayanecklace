import SwiftUI
#if canImport(RealityKit)
import RealityKit
#endif
#if canImport(SceneKit)
import SceneKit
#endif

/// SwiftUI view that renders the Taya necklace 3D model.
///
/// The model is loaded from `Necklace.usdz` in the `TayaIntelligence`
/// resource bundle. Use `yawDegrees` to rotate the model about its
/// vertical axis — callers wire this to scroll position, drag offset, or
/// any other continuous signal they want to drive a subtle parallax with.
///
/// Rendering paths:
/// - iOS: SceneKit (`SCNView` via `UIViewRepresentable`) — `Model3D` is
///   visionOS-only in this SDK, so SceneKit remains the iOS option.
/// - visionOS: SwiftUI's `Model3D`.
/// - macOS / other: static placeholder. (Keeps the macOS/OrbSandbox build
///   clean since `Model3D` is unavailable there.)
public struct NecklaceModel: View {
    public var yawDegrees: Double
    public var pitchDegrees: Double

    public init(yawDegrees: Double = 0, pitchDegrees: Double = 0) {
        self.yawDegrees = yawDegrees
        self.pitchDegrees = pitchDegrees
    }

    public var body: some View {
        #if os(visionOS)
        model3D
        #elseif os(iOS)
        SceneKitNecklaceView(yawDegrees: yawDegrees, pitchDegrees: pitchDegrees)
        #else
        placeholder
        #endif
    }

    #if os(visionOS)
    private var model3D: some View {
        Model3D(named: "Necklace", bundle: .module) { model in
            model
                .resizable()
                .aspectRatio(contentMode: .fit)
                .rotation3DEffect(
                    .degrees(yawDegrees),
                    axis: (x: 0, y: 1, z: 0)
                )
                .rotation3DEffect(
                    .degrees(pitchDegrees),
                    axis: (x: 1, y: 0, z: 0)
                )
        } placeholder: {
            placeholder
        }
    }
    #endif

    private var placeholder: some View {
        Image(systemName: "circle.dotted.circle")
            .font(.system(size: 48, weight: .regular))
            .foregroundStyle(TayaColors.skyBlue.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if os(iOS) && canImport(SceneKit)
import UIKit

/// SceneKit-backed renderer used by `NecklaceModel` on iOS.
///
/// On `makeUIView` we load the USDZ once, re-pivot the model inside a
/// centering container so rotation happens around its visual center, and
/// add a camera positioned to fit the model's bounding box. On
/// `updateUIView` we only mutate the spin node's `eulerAngles`, wrapped in
/// a zero-duration `SCNTransaction` so the rotation tracks SwiftUI state
/// changes 1:1 (no SceneKit-side animation lag).
private struct SceneKitNecklaceView: UIViewRepresentable {
    let yawDegrees: Double
    let pitchDegrees: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var spinNode: SCNNode?
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = true

        guard
            let url = Bundle.module.url(forResource: "Necklace", withExtension: "usdz"),
            let scene = try? SCNScene(url: url)
        else {
            return view
        }

        // Lift all imported children into a single model node so we have
        // one reliable handle regardless of how the USDZ is structured.
        let modelNode = SCNNode()
        for child in scene.rootNode.childNodes {
            child.removeFromParentNode()
            modelNode.addChildNode(child)
        }

        // Wrap the model in a centering container so rotation pivots around
        // the model's visual center rather than its imported origin.
        let (minB, maxB) = modelNode.boundingBox
        let center = SCNVector3(
            (minB.x + maxB.x) / 2,
            (minB.y + maxB.y) / 2,
            (minB.z + maxB.z) / 2
        )
        modelNode.position = SCNVector3(-center.x, -center.y, -center.z)

        let spinNode = SCNNode()
        spinNode.addChildNode(modelNode)
        scene.rootNode.addChildNode(spinNode)

        // Camera framed to fit the largest extent of the model with padding.
        let extents = SCNVector3(
            maxB.x - minB.x,
            maxB.y - minB.y,
            maxB.z - minB.z
        )
        let maxExtent = max(extents.x, max(extents.y, extents.z))

        let camera = SCNCamera()
        camera.fieldOfView = 30
        let fovRadians = Float(camera.fieldOfView) * .pi / 180
        let distance = (Float(maxExtent) / 2) / tan(fovRadians / 2) * 1.6

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, distance)
        scene.rootNode.addChildNode(cameraNode)

        view.scene = scene
        view.pointOfView = cameraNode

        context.coordinator.spinNode = spinNode
        applyRotation(to: spinNode, duration: 0)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let spinNode = context.coordinator.spinNode else { return }
        applyRotation(to: spinNode, duration: Self.followLagSeconds)
    }

    /// Smooths fast SwiftUI updates — without this, a flick that whips
    /// `distance` from +1 to −1 across two frames snaps the model through
    /// the entire range instantly. With a small lag the model trails the
    /// finger and feels weighted.
    private static let followLagSeconds: CFTimeInterval = 0.18

    private func applyRotation(to node: SCNNode, duration: CFTimeInterval) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        node.eulerAngles = SCNVector3(
            Float(pitchDegrees) * .pi / 180,
            Float(yawDegrees) * .pi / 180,
            0
        )
        SCNTransaction.commit()
    }
}
#endif
