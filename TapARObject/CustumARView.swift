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
        let box = ModelEntity(mesh: .generateBox(size: simd_make_float3(0.2, 0.2, 0.2),
                                                 cornerRadius:  0.03))
        box.generateCollisionShapes(recursive: true)
        box.physicsBody =  PhysicsBodyComponent(massProperties: .default, // 質量
                                                material: .generate(friction: 0.1, // 摩擦係数
                                                                    restitution: 0.1), // 衝突の運動エネルギーの保存率
                                                mode: .kinematic)
        let simpleMaterial = SimpleMaterial(color: .purple, isMetallic: false)
        box.model?.materials = [simpleMaterial]
        box.transform = Transform(pitch: 0, yaw: 1, roll: 0)
        anchor.addChild(box)
        anchor.name = "box"
        scene.anchors.append(anchor)
    }
    
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupARConfig() {
        let config = ARWorldTrackingConfiguration()
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
            guard let indexTipPoint = fingerStatus.indexTip?.location else { return }
            let normalizedPoint = VNImagePointForNormalizedPoint(indexTipPoint,
                                                                 Int(screenSize.width),
                                                                 Int(screenSize.height))
            if let modelEntity = self.entity(at: normalizedPoint) as? ModelEntity {
               
            }
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
        
    }
}