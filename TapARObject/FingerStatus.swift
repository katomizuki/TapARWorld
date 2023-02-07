//
//  FingerStatus.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/07.
//

import Foundation
import Vision

final class FingerStatus {
    private let allPoints: [VNRecognizedPointKey : VNRecognizedPoint]

    init(allPoints: [VNRecognizedPointKey : VNRecognizedPoint]) {
        self.allPoints = allPoints
    }
    
    var thumbTip: VNRecognizedPoint? {
        let thumbTip = allPoints[VNHumanHandPoseObservation.JointName.thumbTip.rawValue]
        return thumbTip
    }
    
    var thumbIP: VNRecognizedPoint? {
        let thumbIP = allPoints[VNHumanHandPoseObservation.JointName.thumbIP.rawValue]
        return thumbIP
    }
    
    var thumbMP: VNRecognizedPoint?  {
        let thumbMP = allPoints[VNHumanHandPoseObservation.JointName.thumbMP.rawValue]
        return thumbMP
    }
   
    var thumbCMC: VNRecognizedPoint? {
        let thumbCMC = allPoints[VNHumanHandPoseObservation.JointName.thumbCMC.rawValue]
        return thumbCMC
    }

    var indexTip: VNRecognizedPoint? {
        let indexTip = allPoints[VNHumanHandPoseObservation.JointName.indexTip.rawValue]
        return indexTip
    }
  
    var indexDIP: VNRecognizedPoint? {
        let indexDIP = allPoints[VNHumanHandPoseObservation.JointName.indexDIP.rawValue]
        return indexDIP
    }
    
    var indexPIP: VNRecognizedPoint? {
        let indexPIP = allPoints[VNHumanHandPoseObservation.JointName.indexPIP.rawValue]
        return indexPIP
    }
    
    var indexMCP: VNRecognizedPoint? {
        let indexMCP = allPoints[VNHumanHandPoseObservation.JointName.indexMCP.rawValue]
        return indexMCP
    }
    
    var middleTip: VNRecognizedPoint? {
        let middleTip = allPoints[VNHumanHandPoseObservation.JointName.middleTip.rawValue]
        return middleTip
    }

    var middleDIP: VNRecognizedPoint? {
        let middleDIP = allPoints[VNHumanHandPoseObservation.JointName.middleDIP.rawValue]
        return middleDIP
    }
    var middlePIP: VNRecognizedPoint? {
        let middlePIP = allPoints[VNHumanHandPoseObservation.JointName.middlePIP.rawValue]
        return middlePIP
    }
    var middleMCP: VNRecognizedPoint? {
        let middleMCP = allPoints[VNHumanHandPoseObservation.JointName.middleMCP.rawValue]
        return middleMCP
    }
    var ringTip: VNRecognizedPoint? {
        let ringTip = allPoints[VNHumanHandPoseObservation.JointName.ringTip.rawValue]
        return ringTip
    }
    var ringDIP: VNRecognizedPoint? {
        let ringDIP = allPoints[VNHumanHandPoseObservation.JointName.ringDIP.rawValue]
        return ringDIP
    }
    
    var ringPIP: VNRecognizedPoint? {
        let ringPIP = allPoints[VNHumanHandPoseObservation.JointName.ringPIP.rawValue]
        return ringPIP
    }
    
    var ringMCP: VNRecognizedPoint? {
        let ringMCP = allPoints[VNHumanHandPoseObservation.JointName.ringMCP.rawValue]
        return ringMCP
    }
    
    var littleTip: VNRecognizedPoint? {
        let littleTip = allPoints[VNHumanHandPoseObservation.JointName.littleTip.rawValue]
        return littleTip
    }
    
    var littleDIP: VNRecognizedPoint? {
        let littleDIP = allPoints[VNHumanHandPoseObservation.JointName.littleDIP.rawValue]
        return littleDIP
    }
    
    var littlePIP: VNRecognizedPoint? {
        let littlePIP = allPoints[VNHumanHandPoseObservation.JointName.littlePIP.rawValue]
        return littlePIP
    }
    
    var littleMCP: VNRecognizedPoint? {
        let littleMCP = allPoints[VNHumanHandPoseObservation.JointName.littleMCP.rawValue]
        return littleMCP
    }
    
    var wrist: VNRecognizedPoint? {
        let wrist = allPoints[VNHumanHandPoseObservation.JointName.wrist.rawValue]
        return wrist
    }
}
