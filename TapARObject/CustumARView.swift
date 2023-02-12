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
import MultipeerHelper
import MultipeerConnectivity

final class CustomARView: ARView {
    
    private var request: VNDetectHumanHandPoseRequest!
    private var serialQueue = DispatchQueue(label: "background")
    private var isRequestProcessing = false
    private var fingerStatus: FingerStatus?
    private var anyCancellabls: Set<AnyCancellable> = []
    private var multipeer: MultipeerHelper!
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        createHandRequest()
        setupARConfig()
        setupBox()
        setupSubscribe()
        setupGesture()
        self.multipeer = MultipeerHelper(serviceName: "hand-ar",
                                         sessionType: .both,
                                         delegate: self)
        self.scene.synchronizationService = self.multipeer.syncService
    }
    private func setupBox() {
        let anchor = AnchorEntity()
        anchor.position = simd_make_float3(0, -0.5, -1)
      
        let soad = SoadGeometry()
        soad.generateCollisionShapes(recursive: true)
        soad.physicsBody =  PhysicsBodyComponent(massProperties: .default, // 質量
                                                material: .generate(friction: 0.1, // 摩擦係数
                                                                    restitution: 0.1), // 衝突の運動エネルギーの保存率
                                                mode: .kinematic)
        soad.transform = Transform(pitch: 0, yaw: 1, roll: 0)
        soad.synchronization?.ownershipTransferMode = .autoAccept
        anchor.addChild(soad)
        anchor.name = "soad"
        scene.anchors.append(anchor)
    }
    
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupARConfig() {
        let config = ARWorldTrackingConfiguration()
        config.isCollaborationEnabled = true
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
            guard var normalizedLocation = fingerStatus.indexTip?.location else { return }
            // スクリーン空間
            // Portraitで左下を0,0にする
            normalizedLocation = CGPoint(x: normalizedLocation.y, y: normalizedLocation.x)
            let indexTipScreenLocation = VNImagePointForNormalizedPoint(normalizedLocation,
                                                                 Int(screenSize.width),
                                                                 Int(screenSize.height))
            let cameraOffset = simd_make_float3(0, 0, 0.99)
            let worldInPosition = self.cgPointToWorldspace(indexTipScreenLocation,
                                                           offsetFromCamera: cameraOffset)
            guard let soadGeometry = self.scene.anchors.first(where: { $0.name == "soad"})?.parent as? SoadGeometry else { return }
            print(worldInPosition)
            print(soadGeometry)
            
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
            let displayName = self.multipeer.myPeerID.displayName
            if let data = displayName.data(using: .unicode) {
                multipeer.sendToAllPeers(data)
                entity.runWithOwnership { result in
                    switch result {
                    case .success(let success):
                        let originTransform = Transform(scale: .one,
                                                  rotation: .init(),
                                                  translation: .zero)
                        let largerTransform = Transform(scale: .init(repeating: 1.5),
                                                        rotation: .init(),
                                                        translation: .zero)
                        entity.move(to: largerTransform,
                                    relativeTo: entity.parent,
                                    duration: 0.2)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            entity.move(to: originTransform,
                                        relativeTo: entity.parent,
                                        duration: 0.2)
                        }
                    case .failure(let failure):
                        print(failure.localizedDescription)
                    }
                }
            }
        }
    }
}
extension CustomARView: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        self.executeHandTracking(pixelBuffer: pixelBuffer)
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
            // カメラの平行移動を示した行列
            let planePosMatrix = float4x4(col0, col1, col2, col3)
            // カメラの回転行列
            let camRotMatrix = float4x4(cameraTransform.rotation)

            // Get rotation offset: Y-up is considered the plane's normal, so we
            // rotate the plane around its X-axis by 90 degrees.
        // x軸方向に90ど回転させてるっぽい
            col0 = SIMD4<Float>(1, 0, 0, 0)
            col1 = SIMD4<Float>(0, 0, 1, 0)
            col2 = SIMD4<Float>(0, -1, 0, 0)
            col3 = SIMD4<Float>(0, 0, 0, 1)
            let axisFlipMatrix = float4x4(col0, col1, col2, col3)

            let rotatedPlaneAtPoint = planePosMatrix * camRotMatrix * axisFlipMatrix
            // 作成したクリッピング平面を元にunproject
            let projectionAtRotatedPlane = unproject(cgPoint, ontoPlane: rotatedPlaneAtPoint) ?? camForwardPoint
            let verticalOffset = cameraTransform.matrix.upVector * offsetFromCamera.y
            let horizontalOffset = cameraTransform.matrix.rightVector * offsetFromCamera.x
            return projectionAtRotatedPlane + verticalOffset + horizontalOffset
        }
}

extension CustomARView: MultipeerHelperDelegate {
    func shouldSendJoinRequest(peerHelper: MultipeerHelper, _ peer: MCPeerID, with discoveryInfo: [String : String]?) -> Bool {
        if CustomARView.checkPeerToken(with: discoveryInfo) {
            return true
        } else {
            return false
        }
    }
    
    func receivedData(peerHelper: MultipeerHelper, _ data: Data, _ peer: MCPeerID) {
        print(peerHelper)
    }
    
    func peerJoined(peerHelper: MultipeerHelper, _ peer: MCPeerID) {
        print(peerHelper)
    }
}
