//
//  CustumARView.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/07.
//

import RealityKit
import Vision
import ARKit
import Combine
import RealityGeometries

final class CustomARView: ARView {
    
    private var request: VNDetectHumanHandPoseRequest!
    private var serialQueue = DispatchQueue(label: "background")
    private var isRequestProcessing = false
    private var fingerStatus: FingerStatus?
    private var anyCancellabls: Set<AnyCancellable> = []
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        createHandRequest()
        setupARConfig()
        setupBox()
        setupSubscribe()
        setupGesture()
    }
    private func setupBox() {
        let anchor = AnchorEntity()
        anchor.position = simd_make_float3(0, -0.5, -1)
      
        let soad = ModelEntity(mesh: MeshResource.generateBox(size: 0.5,cornerRadius: 0.1))
        soad.generateCollisionShapes(recursive: true)
        soad.physicsBody =  PhysicsBodyComponent(massProperties: .default, // 質量
                                                material: .generate(friction: 0.1, // 摩擦係数
                                                                    restitution: 0.1), // 衝突の運動エネルギーの保存率
                                                mode: .kinematic)
        soad.transform = Transform(pitch: 0, yaw: 1, roll: 0)
        anchor.addChild(soad)
        anchor.name = "soad"
        scene.anchors.append(anchor)
    }
    
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupARConfig() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal,.vertical]
        session.run(config)
        session.delegate = self
    }
    
    private func createHandRequest()  {
        self.request = VNDetectHumanHandPoseRequest(completionHandler: { vnRequest, error in
            self.isRequestProcessing = false
            if let _ = error {
                return
            }
            guard let results = vnRequest.results else {
                return
            }
            guard let vnObservation = results.first,
                  let handObservation = vnObservation as? VNHumanHandPoseObservation
            else { return }
            self.getHandPoints(handObservation: handObservation)
        })
        self.request.maximumHandCount = 1
    }
    
    private func getHandPoints(handObservation: VNHumanHandPoseObservation) {
        do {
            let allPoints = try handObservation.recognizedPoints(forGroupKey: VNRecognizedPointGroupKey.all)
            self.fingerStatus = FingerStatus(allPoints: allPoints)
        } catch {
        }
    }
    
    private func executeHandTracking(pixelBuffer: CVPixelBuffer) {
        if isRequestProcessing { return }
        serialQueue.async {
            self.isRequestProcessing = true
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            do {
                try handler.perform([self.request])
            } catch {
                self.isRequestProcessing = false
            }
        }
    }
    private func setupSubscribe() {
        let screenSize = UIScreen.main.bounds.size
        scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            guard let self = self else { return }
            guard let fingerStatus = self.fingerStatus else { return }
            guard let normalizedLocation = fingerStatus.indexTip?.location else { return }
            // スクリーン空間
            let indexTipScreenLocation = VNImagePointForNormalizedPoint(normalizedLocation,
                                                                 Int(screenSize.width),
                                                                 Int(screenSize.height))
            let cameraOffset = simd_make_float3(0, 0, 1)
            let worldInPosition = self.cgPointToWorldspace(indexTipScreenLocation,
                                                           offsetFromCamera: cameraOffset)
            print(worldInPosition,"✋")
            self.scene.anchors.first(where: { $0.name == "soad"})?.position = worldInPosition
        }.store(in: &self.anyCancellabls)
    }
    
    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapARView))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func onTapARView(gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard let rayResult = ray(through: location) else { return }
               let results = scene.raycast(origin: rayResult.origin,
                                          direction: rayResult.direction)
        if let result = results.first {
            let entity = result.entity
        }
    }
}
extension CustomARView: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        self.executeHandTracking(pixelBuffer: pixelBuffer)
//        frame.camera.
    }
}

extension CustomARView {
   
    func cgPointToWorldspace(_ cgPoint: CGPoint,offsetFromCamera: SIMD3<Float> ) -> SIMD3<Float> {
            // カメラに垂直なPlaneを作成
        let camForwardPoint = cameraTransform.matrix.position +
        (cameraTransform.matrix.forwardVector * offsetFromCamera.z)
            var col0 = SIMD4<Float>(1, 0, 0, 0)
            var col1 = SIMD4<Float>(0, 1, 0, 0)
            var col2 = SIMD4<Float>(0, 0, 1, 0)
            var col3 = SIMD4<Float>(camForwardPoint.x, camForwardPoint.y, camForwardPoint.z, 1)
            let planePosMatrix = float4x4(col0, col1, col2, col3)

            // カメラの回転行列
            let camRotMatrix = float4x4(cameraTransform.rotation)

            // Get rotation offset: Y-up is considered the plane's normal, so we
            // rotate the plane around its X-axis by 90 degrees.
            col0 = SIMD4<Float>(1, 0, 0, 0)
            col1 = SIMD4<Float>(0, 0, 1, 0)
            col2 = SIMD4<Float>(0, -1, 0, 0)
            col3 = SIMD4<Float>(0, 0, 0, 1)
            let axisFlipMatrix = float4x4(col0, col1, col2, col3)

            let rotatedPlaneAtPoint = planePosMatrix * camRotMatrix * axisFlipMatrix
            let projectionAtRotatedPlane = unproject(cgPoint, ontoPlane: rotatedPlaneAtPoint) ?? camForwardPoint
            let verticalOffset = cameraTransform.matrix.upVector * offsetFromCamera.y
            let horizontalOffset = cameraTransform.matrix.rightVector * offsetFromCamera.x
            return projectionAtRotatedPlane + verticalOffset + horizontalOffset
        }
}

extension float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3.x = translation.x
        columns.3.y = translation.y
        columns.3.z = translation.z
    }

    init(rotationX angle: Float) {
        self = matrix_identity_float4x4
        columns.1.y = cos(angle)
        columns.1.z = sin(angle)
        columns.2.y = -sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationY angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.z = -sin(angle)
        columns.2.x = sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationZ angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.y = sin(angle)
        columns.1.x = -sin(angle)
        columns.1.y = cos(angle)
    }

    init(rotation angle: SIMD3<Float>) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationX * rotationY * rotationZ
    }

    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let yValue = 1 / tan(fov * 0.5)
        let xValue = yValue / aspect
        let zValue = lhs ? far / (far - near) : far / (near - far)
        let x2Value = SIMD4<Float>(xValue, 0, 0, 0)
        let y2Value = SIMD4<Float>(0, yValue, 0, 0)
        let z2Value = lhs ? SIMD4<Float>(0, 0, zValue, 1) : SIMD4<Float>(0, 0, zValue, -1)
        let wValue = lhs ? SIMD4<Float>(0, 0, zValue * -near, 0) : SIMD4<Float>(0, 0, zValue * near, 0)
        self.init()
        columns = (x2Value, y2Value, z2Value, wValue)
    }

    var upVector: SIMD3<Float> {
        return SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)
    }

    var rightVector: SIMD3<Float> {
        return SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)
    }

    var forwardVector: SIMD3<Float> {
        return SIMD3<Float>(-columns.2.x, -columns.2.y, -columns.2.z)
    }

    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
