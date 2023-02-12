//
//  ARFrame.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/11.
//

import ARKit
import UIKit

extension ARFrame {
    
    func depthMapTransformedImage(orientation: UIInterfaceOrientation,
                                  viewPort: CGRect) -> UIImage? {
        guard let pixelBuffer = self.sceneDepth?.depthMap else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return UIImage(ciImage: screenTransformed(ciImage: ciImage,
                                                  orientation: orientation,
                                                  viewport: viewPort))
    }
    
    func confidenceMapToCIImage(pixelBuffer: CVPixelBuffer) -> CIImage? {
        // 読み取りと書き取りをするのでそのフラグを立てる
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        // pixelBufferからポインタを取ってくる
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        // pixelbufferから高さを取得
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        // 画像データの行ごとのバイト数を取得 = ピクセルデータを使うのに必要
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        print(bytesPerRow)
        for i in stride(from: 0,
                        through: bytesPerRow * height,
                        by: MemoryLayout<UInt8>.stride) {
            //ポインタからuint8型アドレスを指定して取ってくる
            let confidenceValue = base.load(fromByteOffset: i,
                                            as: UInt8.self)
            let pixelValue = confienceValueToPixcelValue(confidenceValue: confidenceValue)
            // 同じ場所にピクセルデータとして保存！
            base.storeBytes(of: pixelValue,
                            toByteOffset: i,
                            as: UInt8.self)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return CIImage(cvPixelBuffer: pixelBuffer)
    }
    
    func confienceValueToPixcelValue(confidenceValue: UInt8) -> UInt8 {
        // rgbに変換
        guard confidenceValue <= ARConfidenceLevel.high.rawValue else {return 0}
        return UInt8(floor(Float(confidenceValue) / Float(ARConfidenceLevel.high.rawValue) * 255))
    }
    
    
    func screenStransform(orientation: UIInterfaceOrientation,
                          viewPortSize: CGSize,
                          captureSize: CGSize) -> CGAffineTransform {
        /// 正規化されたアフィン変換
        let normalizedTransform = CGAffineTransform(scaleX: 1.0 / captureSize.width,
                                                    y: 1.0 / captureSize.height)
        // スマホの角度を考慮
        let flipTransform = (orientation.isPortrait) ? CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1) : .identity
        // https://qiita.com/pic18f14k50/items/a4f0f90458d64aa4e672
        let displayTransoform = self.displayTransform(for: orientation,
                                                      viewportSize: viewPortSize)
        // viewport座標にする
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width,
                                                    y: viewPortSize.height)
        print(toViewPortTransform)
        return normalizedTransform.concatenating(flipTransform)
            .concatenating(displayTransoform)
            .concatenating(toViewPortTransform)
    }
    
    func screenTransformed(ciImage: CIImage,
                           orientation: UIInterfaceOrientation,
                           viewport: CGRect) -> CIImage {
        let transform = screenStransform(orientation: orientation,
                                         viewPortSize: viewport.size,
                                         captureSize: ciImage.extent.size)
        print(transform)
        // ciimageを指定したaffine変換を適用させた後にcgrectでクリッピングする。
        return ciImage.transformed(by: transform).cropped(to: viewport)
    }
    
    fileprivate func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer,
                                   pixelFormat: MTLPixelFormat,
                                   planeIndex: Int,
                                   textureCache: CVMetalTextureCache) -> CVMetalTexture? {
        // とりあえずcvpixelbufferの幅と高さを得る
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        //
        let status = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                               textureCache,
                                                               pixelBuffer,
                                                               nil,
                                                               pixelFormat,
                                                               width,
                                                               height,
                                                               planeIndex,
                                                               &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }

    func buildDepthTextures(textureCache: CVMetalTextureCache) -> (depthTexture: CVMetalTexture, confidenceTexture: CVMetalTexture)? {
        guard let depthMap = self.sceneDepth?.depthMap,
            let confidenceMap = self.sceneDepth?.confidenceMap else {
                return nil
        }
        
        guard let depthTexture = createTexture(fromPixelBuffer: depthMap,
                                               pixelFormat: .r32Float,
                                               planeIndex: 0,
                                               textureCache: textureCache),
              let confidenceTexture = createTexture(fromPixelBuffer: confidenceMap,
                                                    pixelFormat: .r8Uint,
                                                    planeIndex: 0,
                                                    textureCache: textureCache) else {
            return nil
        }
        
        return (depthTexture: depthTexture, confidenceTexture: confidenceTexture)
    }
}
